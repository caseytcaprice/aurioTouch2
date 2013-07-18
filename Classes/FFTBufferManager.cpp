#include "FFTBufferManager.h"
#include "CABitOperations.h"
#include "CAStreamBasicDescription.h"

#define min(x,y) (x < y) ? x : y

FFTBufferManager::FFTBufferManager(UInt32 inNumberFrames) :
mNeedsAudioData(0),
mHasAudioData(0),
mFFTNormFactor(1.0/(2*inNumberFrames)),
mAdjust0DB(1.5849e-13),
m24BitFracScale(16777216.0f),
mFFTLength(inNumberFrames/2),
mLog2N(Log2Ceil(inNumberFrames)),
mNumberFrames(inNumberFrames),
mAudioBufferSize(inNumberFrames * sizeof(Float32)),
mAudioBufferCurrentIndex(0)

{
    mAudioBuffer = (Float32*) calloc(mNumberFrames,sizeof(Float32));
    mDspSplitComplex.realp = (Float32*) calloc(mFFTLength,sizeof(Float32));
    mDspSplitComplex.imagp = (Float32*) calloc(mFFTLength, sizeof(Float32));
    mSpectrumAnalysis = vDSP_create_fftsetup(mLog2N, kFFTRadix2);
	OSAtomicIncrement32Barrier(&mNeedsAudioData);
}

FFTBufferManager::~FFTBufferManager()
{
    vDSP_destroy_fftsetup(mSpectrumAnalysis);
    free(mAudioBuffer);
    free (mDspSplitComplex.realp);
    free (mDspSplitComplex.imagp);
}

void FFTBufferManager::GrabAudioData(AudioBufferList *inBL)
{
	if (mAudioBufferSize < inBL->mBuffers[0].mDataByteSize)	return;
	
	UInt32 bytesToCopy = min(inBL->mBuffers[0].mDataByteSize, mAudioBufferSize - mAudioBufferCurrentIndex);
	memcpy(mAudioBuffer+mAudioBufferCurrentIndex, inBL->mBuffers[0].mData, bytesToCopy);
	
	mAudioBufferCurrentIndex += bytesToCopy / sizeof(Float32);
	if (mAudioBufferCurrentIndex >= mAudioBufferSize / sizeof(Float32))
	{
		OSAtomicIncrement32Barrier(&mHasAudioData);
		OSAtomicDecrement32Barrier(&mNeedsAudioData);
	}
}

Boolean	FFTBufferManager::ComputeFFT(int32_t *outFFTData)
{
	if (HasNewAudioData())
	{
        //Generate a split complex vector from the real data
        vDSP_ctoz((COMPLEX *)mAudioBuffer, 2, &mDspSplitComplex, 1, mFFTLength);
        
        //Take the fft and scale appropriately
        vDSP_fft_zrip(mSpectrumAnalysis, &mDspSplitComplex, 1, mLog2N, kFFTDirection_Forward);
        vDSP_vsmul(mDspSplitComplex.realp, 1, &mFFTNormFactor, mDspSplitComplex.realp, 1, mFFTLength);
        vDSP_vsmul(mDspSplitComplex.imagp, 1, &mFFTNormFactor, mDspSplitComplex.imagp, 1, mFFTLength);
        
        //Zero out the nyquist value
        mDspSplitComplex.imagp[0] = 0.0;
        
        //Convert the fft data to dB
        Float32 tmpData[mFFTLength];
        vDSP_zvmags(&mDspSplitComplex, 1, tmpData, 1, mFFTLength);
        
        //In order to avoid taking log10 of zero, an adjusting factor is added in to make the minimum value equal -128dB
        vDSP_vsadd(tmpData, 1, &mAdjust0DB, tmpData, 1, mFFTLength);
        Float32 one = 1;
        vDSP_vdbcon(tmpData, 1, &one, tmpData, 1, mFFTLength, 0);
        
        //Convert floating point data to integer (Q7.24)
        vDSP_vsmul(tmpData, 1, &m24BitFracScale, tmpData, 1, mFFTLength);
        for(UInt32 i=0; i<mFFTLength; ++i)
            outFFTData[i] = (SInt32) tmpData[i];
        
        OSAtomicDecrement32Barrier(&mHasAudioData);
		OSAtomicIncrement32Barrier(&mNeedsAudioData);
		mAudioBufferCurrentIndex = 0;
		return true;
	}
	else if (mNeedsAudioData == 0)
		OSAtomicIncrement32Barrier(&mNeedsAudioData);
	
	return false;
}

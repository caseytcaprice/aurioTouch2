#include <AudioToolbox/AudioToolbox.h>
#include <libkern/OSAtomic.h>
#include <Accelerate/Accelerate.h>

class FFTBufferManager
{
public:
	FFTBufferManager(UInt32 inNumberFrames);
	~FFTBufferManager();
	
	volatile int32_t	HasNewAudioData()	{ return mHasAudioData; }
	volatile int32_t	NeedsNewAudioData() { return mNeedsAudioData; }
    
	UInt32				GetNumberFrames() { return mNumberFrames; }
    
	void				GrabAudioData(AudioBufferList *inBL);
	Boolean				ComputeFFT(int32_t *outFFTData);
    
    void                ClearBuffer(void* buffer, UInt32 numBytes);
	
private:
	volatile int32_t	mNeedsAudioData;
	volatile int32_t	mHasAudioData;
	
    FFTSetup            mSpectrumAnalysis;
    DSPSplitComplex     mDspSplitComplex;
    
    Float32             mFFTNormFactor;
    Float32             mAdjust0DB;
    Float32             m24BitFracScale;
	
	Float32*			mAudioBuffer;
	UInt32				mNumberFrames;
    UInt32              mFFTLength;
    UInt32              mLog2N;
	UInt32				mAudioBufferSize;
	int32_t				mAudioBufferCurrentIndex;
};
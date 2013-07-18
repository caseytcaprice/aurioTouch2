#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "EAGLView.h"

#define USE_DEPTH_BUFFER 1

@interface EAGLView (EAGLViewPrivate)

- (BOOL)createFramebuffer;
- (void)destroyFramebuffer;

@end

@interface EAGLView (EAGLViewSprite)

- (void)setupView;

@end

@implementation EAGLView

@synthesize applicationResignedActive;

// You must implement this
+ (Class) layerClass
{
	return [CAEAGLLayer class];
}


//The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder
{
	if((self = [super initWithCoder:coder])) {
		// Get the layer
		CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
		
		eaglLayer.opaque = YES;
		
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
		
		
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		
		if(!context || ![EAGLContext setCurrentContext:context] || ![self createFramebuffer]) {
			[self release];
			return nil;
		}
		
		animationInterval = 1.0 / 60.0;
		
		[self setupView];
		[self drawView];
	}
	
	return self;
}


- (void)layoutSubviews
{
	[EAGLContext setCurrentContext:context];
	[self destroyFramebuffer];
	[self createFramebuffer];
	[self drawView];
}


- (BOOL)createFramebuffer
{
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	if(USE_DEPTH_BUFFER) {
		glGenRenderbuffersOES(1, &depthRenderbuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
		glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
	}
	
	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
	
	return YES;
}


- (void)destroyFramebuffer
{
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if(depthRenderbuffer) {
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}

- (void)startAnimation
{
	animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
	animationStarted = [NSDate timeIntervalSinceReferenceDate];
}

- (void)stopAnimation
{
	[animationTimer invalidate];
	animationTimer = nil;
}

- (void)setAnimationInterval:(NSTimeInterval)interval
{
	animationInterval = interval;
	
	if(animationTimer) {
		[self stopAnimation];
		[self startAnimation];
	}
}


- (void)setupView
{
	
	// Sets up matrices and transforms for OpenGL ES
	glViewport(0, 0, backingWidth, backingHeight);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrthof(0, backingWidth, 0, backingHeight, -1.0f, 1.0f);
	glMatrixMode(GL_MODELVIEW);
	
	// Clears the view with black
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	///glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
}

// Updates the OpenGL view when the timer fires
- (void)drawView
{
    // the NSTimer seems to fire one final time even though it's been invalidated
    // so just make sure and not draw if we're resigning active
    if (self.applicationResignedActive) return;
    
	// Make sure that you are drawing to the current context
	[EAGLContext setCurrentContext:context];
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	
	[delegate drawView:self forTime:([NSDate timeIntervalSinceReferenceDate] - animationStarted)];
	
	/*
     glRotatef(3.0f, 0.0f, 0.0f, 1.0f);
     
     glClear(GL_COLOR_BUFFER_BIT);
     glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	 */
	
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

// Stop animating and release resources when they are no longer needed.
- (void)dealloc
{
	[self stopAnimation];
	
	if([EAGLContext currentContext] == context) {
		[EAGLContext setCurrentContext:nil];
	}
	
	[context release];
	context = nil;
	
	[super dealloc];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([(id)delegate respondsToSelector:@selector(touchesBegan:withEvent:)])
		[delegate touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([(id)delegate respondsToSelector:@selector(touchesMoved:withEvent:)])
		[delegate touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([(id)delegate respondsToSelector:@selector(touchesEnded:withEvent:)])
		[delegate touchesEnded:touches withEvent:event];
}



- (id <EAGLViewDelegate>)delegate { return delegate; }
- (void)setDelegate:(id <EAGLViewDelegate>)v
{
	delegate = v;
}

@end

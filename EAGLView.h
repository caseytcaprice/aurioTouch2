#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@protocol EAGLViewDelegate
@required
- (void)drawView:(id)sender forTime:(NSTimeInterval)time;
@optional
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface EAGLView : UIView
{
@private
	
	/* The pixel dimensions of the backbuffer */
	GLint backingWidth;
	GLint backingHeight;
	
	EAGLContext *context;
	
	/* OpenGL names for the renderbuffer and framebuffers used to render to this view */
	GLuint viewRenderbuffer, viewFramebuffer;
	
	/* OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist) */
	GLuint depthRenderbuffer;
	
	/* OpenGL name for the sprite texture */
    // bgTexture is used in the app delegate
	GLuint bgTexture;
	
	id <EAGLViewDelegate> delegate;
	
	NSTimer *animationTimer;
	NSTimeInterval animationInterval;
	NSTimeInterval animationStarted;
    
    BOOL applicationResignedActive;
}

- (void)startAnimation;
- (void)stopAnimation;
- (void)drawView;
- (void)setAnimationInterval:(NSTimeInterval)interval;

@property(assign) id <EAGLViewDelegate> delegate;
@property(assign) BOOL applicationResignedActive;

@end

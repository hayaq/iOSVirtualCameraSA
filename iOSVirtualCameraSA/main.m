//
//  main.m
//  iOSVirtualCameraSA
//
//  Created by hayashi on 12/22/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//
#import "QTCamera.h"
#import "SHMVideo.h"

@class ConsoleApp;

static ConsoleApp *sharedApp = NULL;
static void CameraCallback(QTCamera *capture, void **buffers, void *context);
static void SignalHandler(int signum);

@interface ConsoleApp : NSObject{
	SHMVideo *shmVideo;
}
@end

@implementation ConsoleApp

-(id)init{
	self = [super init];
	sharedApp = self;
	return self;
}

-(int)setupCamera:(QTCamera*)_camera{
	NSArray *cameraList = [QTCamera enumerateCameras];
	if( [cameraList count] == 0 ){
		NSLog(@"Error: No camera found");
		return -1;
	}

	NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
	NSInteger cameraIndex = 0;
	
	if( [args objectForKey:@"camera"] ){
		NSString *selectedName = [args stringForKey:@"camera"];
		if( [[NSString stringWithFormat:@"%ld",[selectedName integerValue]] isEqual:selectedName] ){
			cameraIndex = [selectedName integerValue];
		}else{
			for(NSInteger i=0;i<[cameraList count];i++){
				NSString *cameraName = [cameraList objectAtIndex:i];
				NSRange r = [cameraName rangeOfString:selectedName options:NSCaseInsensitiveSearch];
				if( r.location != NSNotFound ){
					cameraIndex = i;
					break;
				}
			}
		}
	}
	
	// size
	NSArray *sizePreset = @[@"640x480",@"480x360",@"320x240"];
	NSString *sizeString = [sizePreset objectAtIndex:0];
	if( [args objectForKey:@"size"] ){
		NSInteger index = [sizePreset indexOfObject:[args stringForKey:@"size"]];
		sizeString = (index==NSNotFound)? [sizePreset objectAtIndex:0] : [args stringForKey:@"size"];
	}
	int captureSize[2];
	if( sscanf([sizeString UTF8String],"%dx%d",captureSize,captureSize+1)!=2 ){
		NSLog(@"Error: Invalid size preset [%s]",[sizeString UTF8String]);
		return -1;
	}
	
	// format
	int captureFormat = 1;
	if( [args objectForKey:@"format"] ){
		captureFormat = (int)[args integerForKey:@"format"];
	}
	
	// fps
	int fps = 30;
	if( [args objectForKey:@"fps"] ){
		NSInteger _fps = [args integerForKey:@"fps"];
		if( _fps >= 0 ){ fps = (int)_fps; }
	}
	
	const char *cameraName = [[cameraList objectAtIndex:cameraIndex] UTF8String];
	const char *formatName = (captureFormat==4)? "BGRA" : "YUV";
	NSLog(@"Camera: [%s] %dx%d %s %dfps",
		   cameraName,captureSize[0],captureSize[1],formatName,fps);
	
	[_camera setInputSource:[NSNumber numberWithInteger:cameraIndex]];
	[_camera setCaptureSize:NSMakeSize(captureSize[0],captureSize[1]) format:captureFormat];
	[_camera setFrameRate:fps];
	[_camera setCaptureCallback:CameraCallback context:NULL];
	
	return 0;
}

-(void)captureFrame:(QTCamera*)camera buffers:(void**)buffers{
	if( !shmVideo ){ return; }
	if( !shmVideo.sharedMemory ){
		[shmVideo allocateBufferWithSize:NSMakeSize(camera.width,camera.height) format:camera.bpp];
	}
	[shmVideo updateVideoBuffer:buffers];
}

-(void)handleSignal:(int)signo{
	[self exit:0];
}

-(void)exit:(int)code{
	NSLog(@"Teminated");
	[shmVideo release];
	exit(code);
}

-(int)run{
	signal(SIGKILL, SignalHandler);
	signal(SIGTERM, SignalHandler);
	signal(SIGINT, SignalHandler);
		
	QTCamera *camera = [[QTCamera alloc] init];
	if( [self setupCamera:camera] < 0 ){
		return -1;
	}
	[camera start];
	
	shmVideo = [[SHMVideo server] retain];
	
	[[NSRunLoop currentRunLoop] run];
	
	return 0;
}

@end

static void CameraCallback(QTCamera *camera, void **buffers, void *context){
	[sharedApp captureFrame:camera buffers:buffers];
}

static void SignalHandler(int signum){
	[sharedApp handleSignal:signum];
}

int main(int argc, const char * argv[])
{
	int ret = 0;
	@autoreleasepool {
		ret = [[[[ConsoleApp alloc] init] autorelease] run];
	}
    return ret;
}


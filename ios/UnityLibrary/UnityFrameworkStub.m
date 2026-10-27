#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "UnityFramework.framework/Headers/UnityFramework.h"

@interface ARCameraView : UIView
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
- (void)startCamera;
- (void)pauseCamera;
- (void)resumeCamera;
@end

@implementation ARCameraView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.sessionQueue = dispatch_queue_create("com.rodeway.camera_session_queue", DISPATCH_QUEUE_SERIAL);
        [self setupCamera];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleOrientationChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleOrientationChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    });
}

- (void)setupCamera {
    dispatch_async(self.sessionQueue, ^{
        self.captureSession = [[AVCaptureSession alloc] init];
        if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
            self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
        }

        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                     mediaType:AVMediaTypeVideo
                                                                      position:AVCaptureDevicePositionBack];
        if (!device) {
            device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        if (!device) {
            // Simulator or hardware without back camera
            return;
        }

        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (error || !input) {
            return;
        }

        if ([self.captureSession canAddInput:input]) {
            [self.captureSession addInput:input];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
            self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            self.previewLayer.frame = self.bounds;
            [self.layer insertSublayer:self.previewLayer atIndex:0];

            dispatch_async(self.sessionQueue, ^{
                [self.captureSession startRunning];
            });
        });
    });
}

- (void)startCamera {
    if (self.captureSession && !self.captureSession.isRunning) {
        dispatch_async(self.sessionQueue, ^{
            [self.captureSession startRunning];
        });
    }
}

- (void)pauseCamera {
    if (self.captureSession && self.captureSession.isRunning) {
        dispatch_async(self.sessionQueue, ^{
            [self.captureSession stopRunning];
        });
    }
}

- (void)resumeCamera {
    [self startCamera];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.previewLayer) {
        self.previewLayer.frame = self.bounds;
        if (self.previewLayer.connection.isVideoOrientationSupported) {
            UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        orientation = ((UIWindowScene *)scene).interfaceOrientation;
                        break;
                    }
                }
            } else {
                orientation = [UIApplication sharedApplication].statusBarOrientation;
            }

            switch (orientation) {
                case UIInterfaceOrientationLandscapeLeft:
                    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                    break;
                case UIInterfaceOrientationLandscapeRight:
                    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                    break;
                case UIInterfaceOrientationPortraitUpsideDown:
                    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                    break;
                default:
                    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
                    break;
            }
        }
    }
}
@end

@implementation UnityAppController
- (void)applicationWillResignActive:(UIApplication*)application {
    if ([self.rootView isKindOfClass:[ARCameraView class]]) {
        [(ARCameraView *)self.rootView pauseCamera];
    }
}
- (void)applicationDidEnterBackground:(UIApplication*)application {
    if ([self.rootView isKindOfClass:[ARCameraView class]]) {
        [(ARCameraView *)self.rootView pauseCamera];
    }
}
- (void)applicationWillEnterForeground:(UIApplication*)application {
    if ([self.rootView isKindOfClass:[ARCameraView class]]) {
        [(ARCameraView *)self.rootView resumeCamera];
    }
}
- (void)applicationDidBecomeActive:(UIApplication*)application {
    if ([self.rootView isKindOfClass:[ARCameraView class]]) {
        [(ARCameraView *)self.rootView resumeCamera];
    }
}
- (void)applicationWillTerminate:(UIApplication*)application {
    if ([self.rootView isKindOfClass:[ARCameraView class]]) {
        [(ARCameraView *)self.rootView pauseCamera];
    }
}
- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application {}
@end

@implementation UnityFramework
static UnityFramework* _instance = nil;
static UnityAppController* _appController = nil;

+ (UnityFramework*)getInstance {
    if (!_instance) { _instance = [[UnityFramework alloc] init]; }
    return _instance;
}
- (void)setDataBundleId:(const char*)t {}
- (void)runEmbeddedWithArgc:(int)argc argv:(char**)argv appLaunchOpts:(NSDictionary*)appLaunchOpts {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityReady" object:nil];
    });
}
- (void)showUnityWindow {
    if (_appController && [_appController.rootView isKindOfClass:[ARCameraView class]]) {
        [(ARCameraView *)_appController.rootView resumeCamera];
    }
}
- (void)pause:(BOOL)pause {
    if (_appController && [_appController.rootView isKindOfClass:[ARCameraView class]]) {
        if (pause) {
            [(ARCameraView *)_appController.rootView pauseCamera];
        } else {
            [(ARCameraView *)_appController.rootView resumeCamera];
        }
    }
}
- (void)unloadApplication {
    if (_appController && [_appController.rootView isKindOfClass:[ARCameraView class]]) {
        [(ARCameraView *)_appController.rootView pauseCamera];
    }
}
- (void)quitApplication:(int)exitCode {
    if (_appController && [_appController.rootView isKindOfClass:[ARCameraView class]]) {
        [(ARCameraView *)_appController.rootView pauseCamera];
    }
}
- (void)sendMessageToGOWithName:(const char*)goName functionName:(const char*)name message:(const char*)msg {}
- (void)registerFrameworkListener:(id<UnityFrameworkListener>)obj {}
- (void)unregisterFrameworkListener:(id<UnityFrameworkListener>)obj {}
- (UnityAppController*)appController {
    if (!_appController) {
        _appController = [[UnityAppController alloc] init];
        _appController.rootView = [[ARCameraView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    }
    return _appController;
}
@end

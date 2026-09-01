#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol UnityFrameworkListener <NSObject>
@optional
- (void)unityDidUnload:(NSNotification*)notification;
- (void)unityDidQuit:(NSNotification*)notification;
@end

@interface UnityAppController : NSObject
@property (nonatomic, strong) UIWindow* window;
@property (nonatomic, strong) UIView* rootView;
@property (nonatomic, copy) void (^unityMessageHandler)(const char* message);
@property (nonatomic, copy) void (^unitySceneLoadedHandler)(const char* name, const int* buildIndex, const bool* isLoaded, const bool* isValid);
@end

@interface UnityFramework : NSObject
+ (UnityFramework*)getInstance;
- (void)setDataBundleId:(const char*)t;
- (void)runEmbeddedWithArgc:(int)argc argv:(char**)argv appLaunchOpts:(NSDictionary*)appLaunchOpts;
- (void)showUnityWindow;
- (void)pause:(BOOL)pause;
- (void)unloadApplication;
- (void)quitApplication:(int)exitCode;
- (void)sendMessageToGOWithName:(const char*)goName functionName:(const char*)name message:(const char*)msg;
- (void)registerFrameworkListener:(id<UnityFrameworkListener>)obj;
- (void)unregisterFrameworkListener:(id<UnityFrameworkListener>)obj;
- (UnityAppController*)appController;
@end

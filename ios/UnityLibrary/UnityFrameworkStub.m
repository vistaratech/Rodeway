#import "UnityFramework.framework/Headers/UnityFramework.h"

@implementation UnityAppController
- (void)applicationWillResignActive:(UIApplication*)application {}
- (void)applicationDidEnterBackground:(UIApplication*)application {}
- (void)applicationWillEnterForeground:(UIApplication*)application {}
- (void)applicationDidBecomeActive:(UIApplication*)application {}
- (void)applicationWillTerminate:(UIApplication*)application {}
- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application {}
@end

@implementation UnityFramework
static UnityFramework* _instance = nil;
+ (UnityFramework*)getInstance {
    if (!_instance) { _instance = [[UnityFramework alloc] init]; }
    return _instance;
}
- (void)setDataBundleId:(const char*)t {}
- (void)runEmbeddedWithArgc:(int)argc argv:(char**)argv appLaunchOpts:(NSDictionary*)appLaunchOpts {}
- (void)showUnityWindow {}
- (void)pause:(BOOL)pause {}
- (void)unloadApplication {}
- (void)quitApplication:(int)exitCode {}
- (void)sendMessageToGOWithName:(const char*)goName functionName:(const char*)name message:(const char*)msg {}
- (void)registerFrameworkListener:(id<UnityFrameworkListener>)obj {}
- (void)unregisterFrameworkListener:(id<UnityFrameworkListener>)obj {}
- (UnityAppController*)appController { return [[UnityAppController alloc] init]; }
@end

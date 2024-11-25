#import <UIKit/UIKit.h>

// ViewController
@interface ViewController : UIViewController
    @property (strong, nonatomic) UILabel *label;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _label = [[UILabel alloc] init];
    _label.text = @"Hello iOS!";
    _label.font = [UIFont systemFontOfSize:48];
    _label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_label];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    _label.frame = self.view.bounds;
}

@end

// AppDelegate
@interface AppDelegate : NSObject <UIApplicationDelegate>
    @property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    ViewController *viewController = [[ViewController alloc] init];
    viewController.view.backgroundColor = [UIColor colorWithRed:0x05 / 255.0 green:0x44 / 255.0 blue:0x5e / 255.0 alpha:1];
    _window.rootViewController = viewController;

    [_window makeKeyAndVisible];

    NSLog(@"Hello iOS!");
    return YES;
}

@end

// Main
int main(int argc, char **argv) {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
}

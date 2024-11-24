#import <UIKit/UIKit.h>

// ViewController
@interface ViewController : UIViewController
    @property (strong, nonatomic) UILabel *label;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.label = [[UILabel alloc] init];
    self.label.text = @"Hello iOS!";
    self.label.font = [UIFont systemFontOfSize:48];
    self.label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.label];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.label.frame = self.view.bounds;
}

@end

// AppDelegate
@interface AppDelegate : UIResponder <UIApplicationDelegate>
    @property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    ViewController *viewController = [[ViewController alloc] init];
    viewController.view.backgroundColor = [UIColor colorWithRed:0x05 / 255.0 green:0x44 / 255.0 blue:0x5e / 255.0 alpha:1];
    self.window.rootViewController = viewController;

    [self.window makeKeyAndVisible];
    return YES;
}

@end

// Main
int main(int argc, char **argv) {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
}

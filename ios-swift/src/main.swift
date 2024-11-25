import UIKit

@main
class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window!.overrideUserInterfaceStyle = .dark

        let viewController = ViewController()
        viewController.view.backgroundColor = UIColor(red: 0x05 / 255.0, green: 0x44 / 255.0, blue: 0x5e / 255.0, alpha: 1)
        window!.rootViewController = viewController

        window!.makeKeyAndVisible()

        NSLog("Hello iOS!")
        return true
    }
}

class ViewController: UIViewController {
    let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "Hello iOS!"
        label.font = UIFont.systemFont(ofSize: 48)
        label.textAlignment = .center
        view.addSubview(label)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        label.frame = view.bounds
    }
}
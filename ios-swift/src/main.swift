import UIKit

// MARK: ViewController
class ViewController: UIViewController {
    let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0x05 / 255.0, green: 0x44 / 255.0, blue: 0x5e / 255.0, alpha: 1)
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

// MARK: AppDelegate
@main
class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window!.overrideUserInterfaceStyle = .dark
        window!.rootViewController = ViewController()
        window!.makeKeyAndVisible()

        NSLog("Hello iOS!")
        return true
    }
}

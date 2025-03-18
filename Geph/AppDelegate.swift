import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize the window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Set the root view controller
        let viewController = ViewController()
        window?.rootViewController = viewController
        
        // Make the window visible
        window?.makeKeyAndVisible()
        
        return true
    }
}
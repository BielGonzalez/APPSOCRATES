import UIKit

// The @UIApplicationMain attribute designates this class as the entry point for the application,
// creating an instance of UIApplication and an instance of AppDelegate.
// It sets up the main event loop and starts processing events.
@UIApplicationMain
// The AppDelegate class serves as the central point for handling application-level lifecycle events.
// It conforms to UIApplicationDelegate to receive these events from the system.
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // The main window of the application.
    // For apps not using Scenes (iOS 13+), this property holds the window that presents the app's UI.
    var window: UIWindow?
    
    // This method is called when the application has finished launching and is ready to run.
    // It's a crucial point for initial setup of the application.
    // - Parameter application: The singleton UIApplication object.
    // - Parameter launchOptions: A dictionary indicating the reason the app was launched (if any).
    //   The key `UIApplication.LaunchOptionsKey` replaced the older `UIApplicationLaunchOptionsKey`.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { // Updated UIApplicationLaunchOptionsKey
        
        // 1. Initialize the application's window.
        // The window is created with the full dimensions of the main screen.
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // 2. Set the root view controller.
        // The ViewController class (defined in ViewController.swift) will be the initial UI presented to the user.
        window?.rootViewController = ViewController()
        
        // 3. Make the window key and visible.
        // This step displays the window and makes it the receiver of touch events.
        window?.makeKeyAndVisible()
        
        // Return true to indicate that the app finished launching successfully.
        return true
    }
    
    // Note: Other UIApplicationDelegate methods like applicationWillResignActive, applicationDidEnterBackground,
    // applicationWillEnterForeground, applicationDidBecomeActive, applicationWillTerminate, etc.,
    // can be implemented here to handle various application lifecycle states.
    // This minimal example only implements didFinishLaunchingWithOptions.
}

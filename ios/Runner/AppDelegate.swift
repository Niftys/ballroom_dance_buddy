import UIKit
import Flutter
#import "Runner/GeneratedPluginRegistrant.h"

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)  // Registers all Flutter plugins

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
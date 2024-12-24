import UIKit
import Flutter
import just_audio
import file_picker
import audio_session
import youtube_player_iframe

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Direct import of GeneratedPluginRegistrant if needed
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    GeneratedPluginRegistrant.register(with: controller)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

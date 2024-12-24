import UIKit
import Flutter
import just_audio
import file_picker
import audio_session
import youtube_player_iframe
#import "Runner/GeneratedPluginRegistrant.h"


@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)  // Manually register plugins

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Dock badge channel: shows the unread-mail count on the app icon.
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "mailcrab/badge",
        binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "setBadge" {
          let label = call.arguments as? String ?? ""
          NSApp.dockTile.badgeLabel = label.isEmpty ? nil : label
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    super.applicationDidFinishLaunching(notification)
  }
}

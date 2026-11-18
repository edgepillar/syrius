import Cocoa
import FlutterMacOS
import ImageIO

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let clipboard = FlutterMethodChannel(
      name: "network.zenon.syrius/image_clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    clipboard.setMethodCallHandler { call, result in
      guard call.method == "writePng" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let bytes = (call.arguments as? FlutterStandardTypedData)?.data,
            bytes.count <= 1024 * 1024,
            let source = CGImageSourceCreateWithData(bytes as CFData, nil),
            (CGImageSourceGetType(source) as String?) == NSPasteboard.PasteboardType.png.rawValue,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
              as? [String: Any],
            let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
            let height = properties[kCGImagePropertyPixelHeight as String] as? Int,
            (1...1024).contains(width), (1...1024).contains(height),
            CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
        result(FlutterError(code: "clipboard-write-failed", message: nil, details: nil))
        return
      }
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      if pasteboard.setData(bytes, forType: .png) {
        result(nil)
      } else {
        result(FlutterError(code: "clipboard-write-failed", message: nil, details: nil))
      }
    }

    super.awakeFromNib()
  }
}

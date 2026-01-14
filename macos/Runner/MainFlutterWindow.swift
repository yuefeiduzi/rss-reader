import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 设置默认窗口大小为 1200x800，方便显示两个栏位
    let contentRect = NSRect(x: 0, y: 0, width: 1200, height: 800)
    let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
    self.setFrame(NSWindow.contentRect(forFrameRect: contentRect, styleMask: styleMask), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

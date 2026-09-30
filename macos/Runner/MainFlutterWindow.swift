import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 默认窗口大小 1200×800，方便显示两个栏位。
    // 注意：加了 .fullSizeContentView 之后内容区包含标题栏，这个尺寸就是窗口尺寸；
    // Flutter 侧会自己给顶栏让出标题栏的高度（见 lib/utils/macos_window.dart）。
    let contentRect = NSRect(x: 0, y: 0, width: 1200, height: 800)
    let styleMask: NSWindow.StyleMask = [
      .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
    ]
    self.setFrame(NSWindow.contentRect(forFrameRect: contentRect, styleMask: styleMask), display: true)

    // 红绿灯适配：标题栏透明 + 标题隐藏，Flutter 画的顶栏一路顶到窗口最上方，
    // 红绿灯浮在它上面（像 Mail / Notes），而不是系统标题栏 + 应用顶栏两层。
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden

    // 内容顶到标题栏之后，AppKit 只认顶部那条真标题栏能拖，
    // Flutter 画的顶栏得靠 method channel 把拖动交给原生窗口（见 MacWindowDragArea）
    let dragChannel = FlutterMethodChannel(
      name: "org.ross.rssReader/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    dragChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "startDrag" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let event = NSApp.currentEvent {
        self?.performDrag(with: event)
      }
      result(nil)
    }

    // 窗口位置：优先恢复上次的位置与大小；第一次打开（没有存档）时居中。
    // 早先写死 NSRect(x: 0, y: 0)，而 Cocoa 坐标原点在左下角，所以窗口
    // 总是开在屏幕左下角。
    let autosaveName = NSWindow.FrameAutosaveName("MainWindow")
    if !self.setFrameUsingName(autosaveName) {
      self.center()
    }
    _ = self.setFrameAutosaveName(autosaveName)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

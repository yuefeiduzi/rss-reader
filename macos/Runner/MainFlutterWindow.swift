import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// 顶栏高度（pt），与 `lib/utils/macos_window.dart` 的 `macOSTopBarHeight` 同源：
  /// Dart 侧启动时会经 method channel 把实际值发过来，这里只是兜底默认值。
  private var topBarHeight: CGFloat = 52

  override func awakeFromNib() {
    // ⚠️ 这行是「顶栏有没有白条」的关键。MainMenu.xib 里的 window 只有
    // titled/closable/miniaturizable/resizable，**没有** fullSizeContentView,
    // 之前这里只是拿它算了个 rect 却从没赋给窗口，于是内容视图从标题栏下方开始，
    // 顶上留出一条原生色带（浅色主题下也是白的，看不出来；深色主题下就是白杠）。
    self.styleMask.insert(.fullSizeContentView)

    // 默认窗口大小 1200×800，方便显示两个栏位。
    // fullSizeContentView 之下内容区就是整窗，这个尺寸即窗口尺寸。
    self.setFrame(NSRect(x: 0, y: 0, width: 1200, height: 800), display: true)

    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 红绿灯适配：标题栏透明 + 标题隐藏，Flutter 的内容铺满整窗（含标题栏那条带），
    // 红绿灯浮在 Flutter 画的顶栏左上角（像 Mail / Notes），而不是系统标题栏 + 应用顶栏两层。
    // Flutter 侧用 macOSTrafficLightInset 给红绿灯让开左边一段（见 lib/utils/macos_window.dart）。
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden

    // 顶栏顶到窗口最上方之后，AppKit 只认那条真标题栏能拖，
    // Flutter 画的顶栏得靠 method channel 把拖动交给原生窗口（见 MacWindowDragArea）
    let dragChannel = FlutterMethodChannel(
      name: "org.ross.rssReader/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    dragChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startDrag":
        if let event = NSApp.currentEvent {
          self?.performDrag(with: event)
        }
        result(nil)
      case "setTopBarHeight":
        // Dart 侧是顶栏高度的唯一来源（lib/utils/macos_window.dart）
        if let height = call.arguments as? Double, height > 0 {
          self?.topBarHeight = CGFloat(height)
          self?.alignTrafficLights()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 窗口位置：优先恢复上次的位置与大小；第一次打开（没有存档）时居中。
    // 早先写死 NSRect(x: 0, y: 0)，而 Cocoa 坐标原点在左下角，所以窗口
    // 总是开在屏幕左下角。
    let autosaveName = NSWindow.FrameAutosaveName("MainWindow")
    if !self.setFrameUsingName(autosaveName) {
      self.center()
    }
    _ = self.setFrameAutosaveName(autosaveName)

    // 窗口尺寸变化、退出全屏后 AppKit 会按标题栏(32pt)重排红绿灯，插件要再对齐一次
    for name in [NSWindow.didResizeNotification, NSWindow.didExitFullScreenNotification] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(windowLayoutDidChange), name: name, object: self)
    }
    DispatchQueue.main.async { [weak self] in self?.alignTrafficLights() }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func windowLayoutDidChange(_ notification: Notification) {
    // AppKit 的重排在本轮事件之后，等一拍再对齐
    DispatchQueue.main.async { [weak self] in self?.alignTrafficLights() }
  }

  /// 把红绿灯下移到顶栏的中线。
  ///
  /// 红绿灯默认居中在标题栏那条 32pt 的带子里（实测按钮中心距窗口顶部 16pt），
  /// 而 Flutter 顶栏是 52pt，中线在 26pt —— 不挪的话红绿灯会比标题高出一截。
  /// AppKit 没有「把红绿灯居中到自定义高度」的接口（那是 NSToolbar 的事），
  /// 只能自己挪按钮。这里按「目标位置 - 当前位置」算位移，可重复调用（已对齐时不动），
  /// 所以 resize / 退出全屏后重跑一遍是安全的。
  private func alignTrafficLights() {
    guard !styleMask.contains(.fullScreen) else { return }
    guard let windowHeight = contentView?.bounds.height else { return }

    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      guard let button = standardWindowButton(type), let container = button.superview else { continue }
      let centerFromTop = windowHeight - button.convert(button.bounds, to: nil).midY
      let dy = centerFromTop - topBarHeight / 2  // 正数 = 需要往上挪
      guard abs(dy) > 0.5 else { continue }
      button.setFrameOrigin(
        NSPoint(
          x: button.frame.origin.x,
          y: button.frame.origin.y + (container.isFlipped ? -dy : dy)))
    }
  }
}

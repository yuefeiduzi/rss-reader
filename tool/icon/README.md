# App 图标

图标是**脚本画出来的**，不是手绘的：`generate_icons.py`，只依赖 Pillow。
改颜色 / 改比例 / 改方向都改这个文件，别在图像编辑器里直接改 PNG —— 那样没人能复现，
也没人知道 16px 那张为什么长这样。

## 网格规则（macOS，Apple 官方那套）

| 项 | 值 | 来源 |
|---|---|---|
| 画布 | 1024×1024 | Apple 模板 |
| 圆角方 | 824×824 居中（四周留 100px） | Apple 模板 |
| 圆角半径 | 185.4 | Apple 模板 |
| 投影 | 向下偏移 8、模糊 6、黑 30% | 按 Flutter 模板图标的投影剖面拟合 |
| 圆角 / 投影 | **必须画进图里** | macOS 不替应用裁圆角、加投影 |

核对方式（脚本外的独立证据）：模板图标的不透明区是 `(101,101)-(923,923)`，
投影延伸到 `(934,944)`；本脚本生成的 PNG 落在同一组数字上：

```bash
python3 -c "
from PIL import Image
a = Image.open('build/icon_drafts/a_1024.png').getchannel('A')
print(a.point(lambda v: 255 if v > 250 else 0).getbbox())  # (101, 101, 923, 923)
print(a.getbbox())                                          # 含投影
"
```

浅底图标（C / D）额外画一条 3px、黑 10–12% 的内描边：白底图标在浅色 Dock /
找色器 / 白色页面上的轮廓全靠它，不然就是一个发白的方块。

## 标记（broadcast mark）

圆点 + 两道 90° 圆弧，圆心重合在圆点上、朝右上开口（RSS 的标准形状）。
尺寸**全部相对 `ink`**（标记外接方框边长）取值，这样任何尺寸下比例都不漂：

```
ink 470   stroke 0.190   gap 0.140   dot 0.145      # nudge (0, +4) 是视觉微调，cap="round"
```

外接方框由两头顶死：左下是圆点的外沿，右上是**最外那道弧的外缘**，
所以 `ink = 圆点半径 + 最外弧外缘半径`，`radii()` 给的就是「外缘」半径。
弧的端头是**与线宽齐平的圆头**，不是鼓出来的球。

> 坑：Pillow 的 `arc(width=)` 是**从外缘往内**画（实测：bbox 半径 90 + 宽 20 → 落笔半径 70…90），
> 而它本身没有 round cap。给弧补端头圆时圆心要放在**线中心**（`r - stroke_w/2`）上，
> 放到外缘（`r`）会鼓出一个球 —— 2026-10-14 改掉的就是这个：之前那版每道弧两头各带一个黑点。
> 端头想改成平切就把 `cap` 设成 `"butt"`，两种对比图见 `build/icon_drafts/cap_compare.png`。

这组数字是在 16 / 24 / 32 / 48 / 64 / 128 / 256px 的真实渲染里逐组比出来的，其中：

- 出过「加粗 + 加大」（现在这组）与「细线 + 小点」两版，前者在 32–64px 明显更清楚
- 出过**小尺寸专用稿**（16/32px 换成「一道弧 + 更大点」的更简形状），实测 16px 并没有更好看，
  还让 16px 的图标看起来像另一个 logo，**不采用** —— 16px 下糊成一团是这类
  「点 + 两道弧」标记的固有代价（官方 RSS 图标同样糊），别为它加细线
- 也用 4× 超采样按目标尺寸直接渲染对比过「1024 缩下来」：差别很小，
  所以实现是「4096 超采样缓冲 → 一次性缩到目标尺寸」，不做分尺寸特判

## 用法

```bash
python3 tool/icon/generate_icons.py drafts              # 四个方向 → build/icon_drafts/
python3 tool/icon/generate_icons.py drafts --only a c   # 只做某几个
```

输出（`build/` 不进仓库）：

- `<方向>_1024.png` … `<方向>_16.png`：1024 / 256 / 128 / 64 / 32 / 16
- `sheet.png`：每个方向一行 —— 大图 + 浅底/深底下的 16/32/64/128 真实像素 + 放大镜

## 定稿：C · 纸墨（2026-10-13 拍板）

米白纸底 + 墨色波纹，橙色只给圆点（`dot_fill`）。候选四个方向留档：

| 方向 | 长什么样 | 一句话 |
|---|---|---|
| A · 经典橙 | 橙底白波纹 | 最像 RSS，缩到小尺寸也最稳 |
| B · 墨蓝夜 | 深墨蓝底 + 橙渐变波纹 + 中心淡蓝光晕 | 深色 Dock 下更稳，像系统图标 |
| **C · 纸墨（选它）** | 米白纸底 + 墨色波纹，圆点是唯一的橙 | 阅读器的气质 |
| D · 白瓷 | 白底 + 橙渐变波纹 | 最接近 macOS 原生 |

## 导出到各平台

```bash
python3 tool/icon/generate_icons.py export c                   # 六个平台一次写全
python3 tool/icon/generate_icons.py export c --only macos web  # 只写某几个
python3 tool/icon/generate_icons.py export c --dry-run         # 只打印计划与回读结果，不写文件
```

写完会**逐条回读**文件（尺寸对不对、该带透明的带没带、`.ico` 里到底压了几档），
因为「跑成功但没动文件」是这类脚本的常见坑。回读结果里出现 ❗ 就是真没对上。

**不引 `flutter_launcher_icons`**：少一个 dev 依赖（也就不会触发 `pubspec.lock` 重解析，
见 AGENTS.md 陷阱 8），而 Web 那套资源本来就不存在、Android adaptive 的安全区也要重排，
自己写更直接。

### 各平台写什么

| 平台 | 模式 | 文件 |
|---|---|---|
| macOS | `macos`：824 圆角方 + 投影 + 四周 100px 留白 | 7 张 `app_icon_{16,32,64,128,256,512,1024}.png`，`Contents.json` **不动**（改了会动 Xcode 工程引用）|
| iOS | `bleed`：满幅方图，圆角由系统裁 | 15 张，**不透明**（App Store 拒收带 alpha 的图标）|
| Android | legacy `bleed` + adaptive 三层 | `mipmap-*/ic_launcher.png`（48dp 档）+ `ic_launcher_foreground.png` / `ic_launcher_monochrome.png`（108dp 档）+ `mipmap-anydpi-v26/ic_launcher.xml` + `drawable/ic_launcher_background.xml`（渐变背景，色号与母版同一组）|
| Web | `bleed` + maskable | `favicon.png`(32) / `icons/Icon-192(512).png` / `Icon-maskable-{192,512}.png` + `manifest.json` + `index.html` 的 `<link>`（只改写 `<!-- icon:start -->` … `<!-- icon:end -->` 之间那块）|
| Windows | `macos` 母版（圆角方 + 透明边） | `app_icon.ico`，一次写 16/24/32/48/64/128/256 七档 |

> Windows 本机不构建，只保证文件写出来、七档齐全，**没有实机验证过**。
> 选 macOS 母版是因为 Explorer 不替应用裁圆角，圆角得自己画；将来真要磨 Windows
> 再单独调（想要满幅就把它改成 `bleed`）。

### 安全区：为什么不能直接把方图缩给 Android / web maskable

标记是斜的（朝右上开口），按外接方框缩放会先把右上角切掉。所以脚本用
`fit_scale(ratio)` 反解倍率：以**画布中心到墨迹最远点**（圆弧端帽、圆点都算）为准，
让最大半径正好落在安全圈上。

| 场景 | 安全圈半径 | 倍率（相对 macOS 设计网格） | 实测墨迹最大半径 |
|---|---|---|---|
| Android adaptive foreground / monochrome | 33/108 dp = 30.6% | 1.0195 | 0.3064 |
| Web / iOS maskable | 40%（标准 80% 直径，留 2% 余量） | 1.2677 | 0.3800（按设计值；背景铺满整块，alpha 量不出来）|

参照系：满幅（`bleed`）的倍率是 `1024/824 = 1.2427`。设计默认比例（倍率 1.0）的墨迹最大半径是
**0.2998** —— 也就是说 Android 的 foreground 按安全圈反解出来是**放大**一点点（×1.02），
不是缩小。

## 验收记录（2026-10-13 / 14）

- **macOS**：`flutter build macos --release` ✓。`iconutil -c iconset` 解出 .app 里的
  `AppIcon.icns`，与仓库 PNG 逐像素比最大差 1（Xcode 重压过一遍），`Assets.car` 里有 10 条
  AppIcon 记录；Dock 里实测看到新图标（见下面的缓存一节）
- **Web**：`flutter build web --release` ✓，`build/web/` 下 favicon / icons / manifest 都在、
  `index.html` 已引用；起 `http.server` 逐个 curl 得到 200 + 正确 content-type
- **Android / iOS / Windows**：**只写了文件，没有实机构建验证** —— 这台机器 Android SDK 缺
  cmdline-tools、iOS 缺 Development Team（AGENTS.md 平台现状）。资源是否被平台接受，
  等打通那两端再验
- **2026-10-14 返工一次**：弧端头的黑球（见上面的坑）改掉后，重新导出六平台、
  macOS / Web 重新构建、Dock 再查一遍；每次改几何都要重跑这套，别只重导出不重建

## 图标缓存：Dock 里还是旧图标，不代表没生效

重新构建、启动，Dock 里仍是 Flutter 模板图标 —— 那是 **macOS 的图标缓存**（实测确认：
缓存里那张与改之前的 `app_icon_128.png` 一模一样）。验证与清缓存的正确姿势：

```bash
APP="build/macos/Build/Products/Release/RSS Reader.app"

# 1) 先证明二进制里是新图标（不依赖任何缓存）
iconutil -c iconset "$APP/Contents/Resources/AppIcon.icns" -o /tmp/ic.iconset && ls /tmp/ic.iconset

# 2) 清缓存（都不需要 sudo）
pkill -f "RSS Reader.app/Contents/MacOS"
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP"
killall iconservicesagent Finder Dock
```

之后 `open "$APP"` 就是新图标了。

> **别用 `qlmanage -t` 看缩略图** —— 它会一直卡住不返回（本机实测），
> 上面那套 `iconutil` 解包比对才是可靠路径。

# macOS 首次打开：添加信任

RSS Reader 的 macOS 包**没有 Apple 签名/公证**，Gatekeeper 会在首次打开时拦下它。
**这不代表包坏了** —— 按下面放行一次即可，之后双击就能打开。

## 为什么没有签名

签名并公证需要 Apple Developer 账号（99 USD/年）与 Developer ID 证书。这个项目的形态
用不上它，于是改用「放行说明 + SHA256 校验和」兜住体验 —— 和
[openOTP](https://github.com/yuefeiduzi/openOTP) 的处理方式一致。

构建产物是 **ad-hoc 签名**（`CODE_SIGN_IDENTITY = "-"`），`spctl -a -t exec`
会判 `rejected`。**自己构建、自己装的完全不受影响**（实测从只读 DMG 卷直接启动也能跑）；
会被拦的只有「从网上下载来的包」—— 因为下载物带 quarantine 标记。

> 顺带说清一件事：**换成自签名证书解决不了这个问题**。自签证书不在别人的信任库里，
> 下载者那边照样被拦，只是提示语不同。唯一能过的是 Apple 签发的 Developer ID + 公证。

## 1. 放行

把 `RSS Reader.app` 拖进「应用程序」，然后照系统给出的那条提示做：

| 系统提示 | 做法 |
|---|---|
| 「无法验证开发者」/「Apple 无法检查它是否包含恶意软件」 | 在「应用程序」里**右键点击** App →「打开」，弹窗里再点一次「打开」 |
| 「已损坏，无法打开，你应该将它移到废纸篓」 | 终端执行 `xattr -dr com.apple.quarantine "/Applications/RSS Reader.app"`，然后正常打开 |

两者都是在清下载时打上的 quarantine 标记。首次放行后系统会记住这个 App。
不想敲命令的话，等价做法是「系统设置 → 隐私与安全性」底部对本次启动点「仍要打开」。

> 为什么两条都写：真实下载路径上到底弹哪一条**未实测**（本机构建的包不带 quarantine 位，
> 复现不出来）。openOTP 的文档也同时写了两条。

## 2. 核对下载（可选）

`SHA256SUMS.txt` 与 DMG 一起发布，用来确认下载完整：

```bash
cd ~/Downloads
shasum -a 256 -c SHA256SUMS.txt
```

**以 Release 附带的那个 `SHA256SUMS.txt` 为准** —— 它是打包时现场算的。
本文件不写固定哈希值：重新构建一次值就会变，写死了只会误导人
（标签指向的提交是冻结的，但同一份源码在不同机器上重编也可能得到不同字节）。

## 3. 数据放在哪

沙盒应用按 bundle id 分目录：

```
~/Library/Containers/org.ross.rssReader/
```

**改包名会换容器路径**，等于换一份新数据 —— 旧数据要手动搬过去并把 plist 改名，
再 `killall cfprefsd` 清缓存。详见 [../AGENTS.md](../AGENTS.md) 的「包名与数据位置」。

## 只有 Apple Silicon 的机器？

不需要担心：DMG 里是 **universal 二进制**（`x86_64` + `arm64`），
Intel Mac 和 Apple Silicon 都能跑。用 `lipo -archs` 可以自己确认：

```bash
lipo -archs "/Applications/RSS Reader.app/Contents/MacOS/RSS Reader"
# → x86_64 arm64
```
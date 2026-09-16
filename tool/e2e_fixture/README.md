# 端到端测试 fixture

一组**故意构造的** RSS / Atom / HTML 文件，用来在本地跑通完整链路并回归已修过的缺陷。

真实 RSS 站点不适合做这件事：它们不发 CORS 头（Web 端抓不到）、内容会变、
日期不可控、也没有「摘要刚好不足 200 字符」这种边界。

## 为什么 Web 端需要它

`RssService` 设置了自定义 `User-Agent`，请求因此成为「非简单请求」，浏览器会先发
CORS 预检；而真实 RSS 服务器不响应预检，请求被直接拦截。**这是架构限制，不是
bug，改代码解决不了**，需要 CORS 代理层。

本 fixture 带上 `Access-Control-Allow-Origin: *`，于是 Web 端能跑通完整解析链路，
从而让「解析是否正确」这件事可以被回归测试。

## 跑起来

```bash
# 1. 构建并托管应用
flutter build web --release
python3 -m http.server 8099 --directory build/web

# 2. 另开一个终端，起 fixture
python3 tool/e2e_fixture/serve.py 8100
```

在应用里添加：

| 源 | 地址 | 期望 |
|---|---|---|
| RSS | `http://127.0.0.1:8100/feed.xml` | 4 篇文章 |
| Atom | `http://127.0.0.1:8100/atom.xml` | 2 个条目 |

> 别用「同路径 + 不同 query」（比如 `feed.xml?v=2`）来造第二个源。
> 早期实现的 `_generateId` 只取 host + path，两者会撞成同一个 id；
> 要造第二个源请换个真实路径。

## 每份文件在回归什么

| 文件 | 覆盖的缺陷 |
|---|---|
| `feed.xml` 第 1 篇 → `article1.html` | 相对图片路径补全（`/img.png`）；懒加载 `data-src` 写回 `src`；HTML 渲染（标题层级 / 列表 / 代码块 / 引用 / 行内代码）；`nav`/`footer` 剥离 |
| `feed.xml` 第 2 篇 → `article2.html` | 摘要够长时**不应**发起全文抓取（若日志里出现对它的请求即为回归） |
| `feed.xml` 第 3 篇 → `article3.html` | 摘要不足 200 字符时抓全文；`fetchFullContent` 的 `Uint8List` 解码 |
| `feed.xml` 第 4 篇 | 只用 `dc:date`、没有 `pubDate`：期望显示 `2020-01-02 03:04`，而不是「刚刚」 |
| `atom.xml` | 每个 entry 只有 `<updated>` 没有 `<published>`：曾因把 `DateTime` 传给期望 `String` 的形参而整源抛 TypeError |

### 一个故意的陷阱

`article1.html` 里的懒加载图片写的是：

```html
<img src="/placeholder.png" data-src="/img2.png">
```

**`placeholder.png` 故意不存在。** 如果它出现在 fixture 服务器的日志里，说明
「把 `data-src` 写回 `src`」这条逻辑回归了——渲染引擎只认 `src`，没有回写就会去
取占位图。

## 手工验证时的几个坑

1. **改了 fixture 先重启服务器。** `serve.py` 已发 `Cache-Control: no-store`，
   但浏览器里可能还留着加这个头之前缓存的响应。最稳妥的做法是换个文件路径
   （比如 `feed2.xml`）或清掉该站点的缓存。
2. **看服务器日志确认请求真的发出去了。** 界面上没变化时，先分清是「请求没发」
   还是「解析结果不对」——只看界面容易误判成解析 bug。
3. **断言「未读徽标」之前先查 `isRead`。** 界面上没有徽标，可能只是因为那篇
   确实已读。曾经把这种情况误报成 bug。
4. **改 `feed.xml` 的 item 数量会改变未读计数**，依赖计数的断言要一起改。
5. **看日志时要分清是 curl 还是应用发的。** 自己用 curl 探测过
   `placeholder.png` 之后，日志里就会出现一条 404，很容易误判成回归。
   判断方法：应用的请求总是紧跟在 `GET /feed.xml` 之后。

## 自动化到什么程度

目前这套 fixture 是**手工驱动**的：起两个服务器，然后在浏览器里点。
`docs/known-issues.md` 记录了完整的手工验证步骤与截图结论。

还没有自动化。要做的话，方向是加一个 widget test：
用 `SharedPreferences.setMockInitialValues` 注入列表状态，把 `RssService` 换成
指向本地 fixture 的实现，断言渲染结果。难点是网络层目前不可注入
（见 `TODO.md` 的「工程」一节）。
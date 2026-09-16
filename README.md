# 屏记 · Screen Time Journal

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows-lightgrey.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B.svg)]()

一款主打「**记录**」的屏幕时间统计软件：可自定义分类、一个应用多个标签、**永久**保留使用数据（卸载不丢、重装叠加）、应用评分与来源链接、单日限额提醒、WebDAV 多设备同步、完整备份。

- 主平台：**Android**
- 适配：**Windows**（同一套 Flutter 代码）
- 同步：标准 **WebDAV**（坚果云 / 群晖 / Nextcloud / 自建等），手动点击、增量合并

---

## 功能一览

### 分类与标签
- 自带「游戏 / 小说 / 动漫 / 影视」四个分类，可改名、改色、换图标、删除。
- 可自由新建任意分类（12 种颜色、23 个图标）；**分类图标支持自定义图片**（相册选图 + 1:1 裁剪）。
- **一个应用可以贴多个分类标签**，统计时在每个标签下各计一次。
- 新装应用自动进入「未分类」兜底；分类页可批量打标签。

### 永久记录（核心差异）
- 统计粒度：**日 / 周 / 月 / 年 / 永久**，另有**自定义日期区间**（任意起止，最近 5 年）。
- 数据按「应用 + 设备 + 天」落库，应用**卸载后记录仍然保留**；重新安装后自动识别并**叠加**统计，重装次数 +1。
- 首次使用可一键**导入系统里已保留的历史使用时间**（Android 系统通常保留数月到约一年的日聚合），不必从零开始。

### 应用详情
- 今日 / 本周 / 本月 / 本年 / 永久时长，柱状图 + 24 小时时间轴。
- 平均每日、当前连续使用天数、最长连续、最高单日使用量。
- 安装日期（**可手动编辑**）。
- 应用描述与 **1~10 分评分**。
- **软件来源**：可加纯文字备注，也可加链接（GitHub、夸克网盘、Telegram、应用商店等），点击直接调起对应应用 / 浏览器。
- 单日使用限额：设置分钟数，到达后全屏提醒并回到桌面。

### 同步与备份
- **WebDAV 同步（手动点击，非自动）**：
  - 只同步「使用时间统计 + 应用字典」，按设备 / 天**增量合并，只增不覆盖、不删除**；
  - **不同步**分类、评分、描述、来源、限额等个人编辑（这些请用备份迁移）。
  - 手机与电脑登录同一 WebDAV 即可互通。
- **手动完整备份**：导出单个 JSON（含全部统计、分类、评分、描述、来源、限额、安装日期）；
  - 导入支持「增量合并（不覆盖本地编辑）」与「覆盖恢复（二次确认）」。

### 对比与界面
- 对比视图：今日 vs 昨日、本周 vs 上周、本月 vs 上月、本年 vs 上年，双柱图 + 环比涨跌。
- **环形图点击交互**：点击分类扇区放大高亮，中心显示该分类名称与时长，再点取消。
- **24 小时分布图**：只显示有使用的小时，渐变圆角柱体。
- **主题**：跟随系统 / 浅色 / 深色，8 种强调色（Material 3）。
- **多语言**：中文 / English（可跟随系统）。
- Material 3 清爽界面，底部四 Tab：统计 / 分类 / 对比 / 设置；首次启动引导开启所需权限。

---

## 平台差异与重要限制（请先阅读）

| 能力 | Android | Windows |
|---|---|---|
| 使用时间采集 | 系统 `UsageStatsManager` 权威数据 | 本软件内置前台窗口轮询（约 5 秒粒度） |
| 导入历史 | 可导入系统已保留的历史 | **无系统历史，只能从安装本软件起开始记录** |
| 卸载保留 / 重装叠加 | ✅ | ✅（exe 路径为标识） |
| 单日限额 | 前台服务检测 + 全屏提醒 + 回桌面 | 最小化全部窗口（同机统计仍在记录） |
| 开机自启 | 开机广播恢复监控服务 | 写入当前用户「启动」注册表项 |
| WebDAV / 备份 / 评分 / 来源 / 对比 | ✅ | ✅ |

**关于「到达限额强制退出」的 Android 限制（务必知悉）**
普通第三方应用**没有权限强制结束其他应用**（`force-stop` / `killBackgroundProcesses` 对其他应用无效）。屏记的实现是：
1. 一个低打扰的常驻前台服务每约 20 秒核对当日各应用总时长；
2. 到达限额时弹出**全屏红色遮挡提醒**（锁屏可显示、拦截返回键），并震动；
3. 通过**无障碍服务的「回到桌面」全局动作**（或标准桌面 Intent）返回桌面。

因此它能可靠地「打断并拉回桌面」，但不是系统级的彻底封禁；无障碍权限仅用于执行回桌面动作，**不监听、不读取、不上传任何界面内容**。

**权限说明（Android）**
- 使用情况访问权限（核心，读取使用统计）；
- 电池优化白名单 / 厂商自启动（保证后台不被杀）；
- 悬浮窗、通知（限额提醒与常驻服务）；
- 无障碍（仅限额时回桌面，可不授予，不授予则用标准桌面 Intent 兜底）；
- 开机自启、震动、查询应用列表。

---

## 构建

环境：Flutter 3.47 (Dart 3.13)、Android minSdk 24 / targetSdk 跟随 Flutter、Windows 需 Visual Studio（含「使用 C++ 的桌面开发」）。

国内网络建议先设置镜像：

```powershell
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

拉依赖与检查：

```bash
flutter pub get
flutter analyze
flutter test
```

构建 Android APK：

```bash
flutter build apk --debug        # 调试包
flutter build apk --release      # 发布包
```

> 发布包使用**正式签名**：密钥库 `android/app/screenjournal-release.jks`（PKCS12，RSA 2048，有效期 10000 天），
> 配置在 `android/key.properties`。**密钥库文件与密码（`android/app/.keystore-password.txt`）务必离线备份**——
> 丢失或泄露会导致已发布版本无法更新、身份被盗用。若 `key.properties` 不存在则回退 debug 签名。
> 图标字体使用 `--no-tree-shake-icons` 构建以完整保留分类图标。

构建 Windows 桌面：

```bash
flutter build windows --debug
# 产物在 build\windows\x64\runner\Debug\屏记.exe（Release 在 ...\Release\）
```

> Windows 构建插件需要**符号链接支持**：请在「设置 → 隐私和安全性 → 开发者选项」中打开**开发者模式**，否则会提示
> `Building with plugins requires symlink support`。

### WebDAV 配置示例
- 服务器地址：你的 WebDAV 根 URL，例如坚果云 `https://dav.jianguoyun.com/dav/`；
- 用户名 / 密码：坚果云等需要在账号设置里生成**应用密码**，不是登录密码；
- 同步目录：任意名称，如 `screentime`（不存在会自动创建）。

---

## 数据存放与口径
- 本地数据库：应用私有目录下 `screen_time_journal.db`（SQLite，WAL）。
- 一天按**设备本地时区**的 00:00~24:00 切分；一周从**周一**开始。
- 「永久」= 该应用全部日统计之和；平均每日 = 永久总量 ÷（今天 − 最早使用日 + 1）；连续天数阈值为当日使用 ≥ 1 分钟。
- 多设备同一天的时长按「设备 + 天」分别保存后相加，同步只增不覆盖。

## 目录结构
```
lib/
  core/        日期区间、格式化
  data/        SQLite 数据访问与模型
  services/    原生桥、采集、统计、WebDAV、同步备份
  state/       AppState（Provider）
  ui/          引导页、统计/分类/对比/设置、应用详情、图表组件
android/       Kotlin：UsageStats 采集、前台监控服务、限额全屏页、无障碍、开机广播
windows/runner C++：前台窗口轮询、MethodChannel、开机自启、回桌面
```

---

## 开源协议

本项目以 **MIT License** 开源，详见 [LICENSE](LICENSE)。

- 欢迎提交 [Issue](https://github.com/) 反馈问题与建议；
- 欢迎 Fork / PR 参与开发；
- 发布版本与签名说明见 [CHANGELOG.md](CHANGELOG.md)。

> 注意：`android/app/screenjournal-release.jks` 等签名密钥文件**不会**进入仓库，请自行保管。

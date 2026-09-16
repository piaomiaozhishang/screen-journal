/// 轻量国际化：以中文为 key，切换到英文时查表；未收录的键回退中文。
/// 语言由 main.dart 在 build 时同步（AppStrings.lang），切换后全树重建。
class AppStrings {
  static String lang = 'zh';

  static const Map<String, String> _en = {
    // ---- 应用 / 导航 ----
    '屏记': 'Screen Journal',
    '统计': 'Stats',
    '分类': 'Categories',
    '对比': 'Compare',
    '设置': 'Settings',
    // ---- 区间 ----
    '日': 'Day',
    '周': 'Week',
    '月': 'Month',
    '年': 'Year',
    '永久': 'All',
    // ---- 通用 ----
    '保存': 'Save',
    '取消': 'Cancel',
    '删除': 'Delete',
    '添加': 'Add',
    '编辑': 'Edit',
    '名称': 'Name',
    '链接': 'Link',
    '文字': 'Text',
    '分钟': 'min',
    '打开设置': 'Open settings',
    '去开启': 'Enable',
    '已开启': 'Enabled',
    '已允许': 'Allowed',
    '未分类': 'Uncategorized',
    '暂无数据': 'No data',
    '上一步': 'Back',
    '下一步': 'Next',
    '重新导入': 'Re-import',
    // ---- 引导页 ----
    '欢迎使用屏记': 'Welcome to Screen Journal',
    '一款“永久记录”的屏幕时间账本：\n\n': 'A permanent screen-time ledger:\n\n',
    '• 自带游戏 / 小说 / 动漫 / 影视分类，可随意增删改\n': '• Built-in Game / Novel / Anime / Video categories, fully editable\n',
    '• 一个应用可以贴多个分类标签，卸载后数据永不丢失\n': '• One app can carry multiple tags; data survives uninstalls\n',
    '• 日、周、月、年、永久统计，支持评分、来源链接与使用限额\n': '• Daily / weekly / monthly / yearly / lifetime stats, rating, source links & limits\n',
    '• WebDAV 手动增量同步，手机与电脑数据合并不覆盖': '• Manual WebDAV incremental sync, merge-only across devices',
    '授予“使用情况访问权限”': 'Grant Usage Access',
    '这是屏幕时间统计的核心权限，屏记需要它读取各应用的前台使用时长。\n\n': 'This is the core permission for screen-time tracking. Screen Journal needs it to read foreground usage.\n\n',
    '点击下方按钮 → 在系统列表中找到「屏记」→ 允许使用情况访问。': 'Tap the button below → find "Screen Journal" in the system list → allow usage access.',
    '导入已有使用时间': 'Import Existing History',
    '不必从零开始：屏记可以读取手机系统已经记录的应用使用时间（通常可回溯数月，': 'No need to start from zero: Screen Journal can read usage history already kept by the system (usually months back, ',
    '因厂商而异），并与之后的记录永久叠加。\n\n建议现在导入，之后也可以在设置中再次操作。': 'varies by vendor), merged permanently with future records.\n\nImport now; you can also redo it later in Settings.',
    '立即导入历史记录': 'Import history now',
    '导入中…': 'Importing…',
    '正在读取系统保留的历史记录…': 'Reading system history…',
    '关闭电池优化（保持后台统计）': 'Disable Battery Optimization',
    '把屏记加入电池优化白名单，避免系统杀死后台统计服务。\n\n': 'Add Screen Journal to the battery whitelist so the system won\'t kill background tracking.\n\n',
    '部分国产系统还需要在“自启动管理”中允许屏记自启动，可一并设置。': 'Some OEM systems also require enabling auto-start for Screen Journal in the autostart manager.',
    '加入电池白名单': 'Add to whitelist',
    '电池白名单已设置': 'Whitelisted',
    '打开厂商自启动设置': 'Open autostart settings',
    '限额强提醒（可选）': 'Usage Limit Alert (optional)',
    '当某个应用达到你设定的每日使用限额时，屏记会全屏提醒并回到桌面。\n\n': 'When an app reaches its daily limit, Screen Journal shows a full-screen alert and returns to home.\n\n',
    '需要两项权限：\n① 悬浮窗（全屏遮挡）\n② 无障碍服务（执行“回到桌面”）\n\n': 'Two permissions needed:\n① Overlay (full-screen cover)\n② Accessibility (go home)\n\n',
    '说明：受 Android 系统限制，普通应用无法强制关闭其他应用，': 'Note: due to Android restrictions, normal apps cannot force-close other apps; ',
    '这是无 root 下最严格的实现方式。': 'this is the strictest approach without root.',
    '① 允许悬浮窗': '① Allow overlay',
    '悬浮窗已允许': 'Overlay allowed',
    '② 开启无障碍服务': '② Enable accessibility',
    '无障碍已开启': 'Accessibility on',
    '通知权限（可选）': 'Notification Permission (optional)',
    '后台统计服务需要显示一条常驻通知，以保证稳定运行。请允许通知。': 'The background service shows a persistent notification to stay alive. Please allow notifications.',
    '开启通知': 'Allow notifications',
    'Windows 端说明': 'Windows Notes',
    'Windows 端会从前台活动窗口记录各软件使用时间，按 exe 识别应用，': 'On Windows, Screen Journal tracks the foreground window and identifies apps by exe, ',
    '统计、分类、限额、图表与 WebDAV 同步功能与手机端一致。\n\n': 'with stats, categories, limits, charts and WebDAV sync identical to Android.\n\n',
    '可选择开机自动启动屏记。': 'You can enable auto-start on login.',
    '设置开机自启': 'Enable auto-start',
    '准备就绪': 'Ready',
    '点击完成后屏记将开始后台统计。你随时可以在「设置 → 权限管理」中调整这些权限。': 'Tap finish to start background tracking. You can adjust permissions anytime under Settings → Permissions.',
    '点击完成进入屏记，统计将从现在开始。': 'Tap finish to enter Screen Journal; tracking starts now.',
    '完成，进入屏记': 'Finish',
    // ---- 主界面 ----
    '使用总时长': 'usage total',
    '所选区间使用总时长': 'Selected range total',
    '分类占比': 'Categories',
    '总计': 'Total',
    '应用排行': 'Top Apps',
    '暂无使用记录，下拉可立即刷新': 'No usage yet — pull down to refresh',
    '已卸载': 'Uninstalled',
    '今天 24 小时分布': 'Today by hour',
    '本周每日时长': 'This week by day',
    '本月每日时长': 'This month by day',
    '今年每月时长': 'This year by month',
    '每月时长（永久）': 'By month (all time)',
    '所选区间每日时长': 'Selected range by day',
    '自定义区间': 'Custom range',
    '清除自定义区间': 'Clear custom range',
    // ---- 分类 ----
    '新建分类': 'New category',
    '编辑分类': 'Edit category',
    '创建': 'Create',
    '分类名称': 'Category name',
    '例如：学习、社交、购物…': 'e.g. Study, Social, Shopping…',
    '图标': 'Icon',
    '颜色': 'Color',
    '删除分类': 'Delete category',
    '请先新建一个分类': 'Create a category first',
    '添加应用到该分类': 'Add apps to this category',
    '添加应用': 'Add apps',
    '加入哪个分类？': 'Which category?',
    '选择应用（可跨分类多选）': 'Select apps (multi-select across categories)',
    '所有应用都已分类\n新装应用会自动出现在这里': 'All apps are categorized\nNew apps will show up here',
    '移出该分类': 'Remove from category',
    // ---- 应用详情 ----
    '应用详情': 'App details',
    '累计时长': 'Total',
    '平均每日': 'Daily avg',
    '当前连续': 'Current streak',
    '最长连续': 'Longest streak',
    '最高单日': 'Best day',
    '使用天数': 'Active days',
    '安装日期': 'Installed',
    '设置日期': 'Set date',
    '当前未安装 · 数据保留': 'Uninstalled · data kept',
    '评分与描述': 'Rating & Notes',
    '不评分': 'No rating',
    '未评分': 'Unrated',
    '记录你对这个应用的评价、用途、注意事项…': 'Notes: review, purpose, caveats…',
    '软件来源': 'Sources',
    '添加来源': 'Add source',
    '编辑来源': 'Edit source',
    '添加下载页面、GitHub、网盘、Telegram 等链接，点击即可跳转。': 'Add links (download page, GitHub, cloud drive, Telegram…); tap to open.',
    '例如：GitHub 发布页': 'e.g. GitHub releases',
    '例如：朋友分享的安装包': 'e.g. APK shared by a friend',
    'https://… 或 tg://、quark:// 等': 'https://… or tg://, quark:// etc.',
    '每日使用限额': 'Daily limit',
    '开启后，当日使用达到限额将被强制提醒并回到桌面。': 'When on, exceeding the daily limit triggers a full-screen alert and returns home.',
    '达到限额时会全屏提醒并自动回到桌面（需在引导/设置中开启悬浮窗与无障碍权限）。': 'On limit, a full-screen alert appears and returns home (requires overlay & accessibility permissions).',
    '受 Android 限制，普通应用无法直接强制关闭其他应用。': 'Due to Android restrictions, apps cannot force-close other apps directly.',
    '今日已用': 'Used today',
    '无法打开链接': 'Cannot open',
    '可能未安装对应应用': 'the app may not be installed',
    '打开失败': 'Open failed',
    '已导出': 'Exported',
    '导入失败': 'Import failed',
    '导入失败：': 'Import failed: ',
    '确认删除「': 'Delete "',
    '」吗？\n该分类下的应用不会被删除，会自动回到“未分类”。': '"? Apps in it are not deleted; they return to Uncategorized.',
    '还没有应用归入「': 'No apps in "',
    '」\n点击右上角添加': '"\nTap the corner button to add',
    '相比上': 'vs last ',
    '增加': 'up',
    '减少': 'down',
    '上传本机': 'uploaded ',
    ' 条统计。': ' local stat(s).',
    '同步成功：合并了': 'Synced: merged ',
    ' 台设备、': ' device(s), ',
    ' 条远端统计，': ' remote stat(s), ',
    '上次': 'Last ',
    '初始化失败：\n': 'Init failed:\n',
    '分类标签': 'Category tags',
    '选择分类（可多选）': 'Select categories (multi)',
    '还没有分类，请到“分类”页新建': 'No categories yet — create one in Categories',
    '应用记录不存在': 'App record not found',
    // ---- 对比 ----
    '24 小时对比': '24h comparison',
    '按日对比': 'By day',
    '按月对比': 'By month',
    '周一 ~ 周日对比': 'Mon–Sun comparison',
    '今天': 'Today',
    '昨天': 'Yesterday',
    '本周': 'This week',
    '上周': 'Last week',
    '本月': 'This month',
    '上月': 'Last month',
    '今年': 'This year',
    '去年': 'Last year',
    '应用对比': 'App comparison',
    '上一周期无记录': 'No records in previous period',
    // ---- 设置 ----
    '数据与同步': 'Data & Sync',
    'WebDAV 同步': 'WebDAV Sync',
    '手动点击同步，多设备统计增量合并不覆盖': 'Manual sync; merges stats across devices without overwriting',
    '备份与恢复': 'Backup & Restore',
    '手动导出 / 导入完整备份（含分类、评分、描述、来源、限额）': 'Export / import full backup (categories, ratings, notes, sources, limits)',
    '导入系统历史记录': 'Import system history',
    '读取手机已有的应用使用时间（仅首次可用）': 'Read usage history already on this phone (first time only)',
    '正在读取系统历史记录…': 'Reading system history…',
    '运行与权限': 'Running & Permissions',
    '后台监控服务': 'Background monitor',
    '用于限额实时提醒；关闭后统计仍会在打开 App 时回填': 'Real-time limit alerts; stats still backfill when the app opens',
    '权限管理': 'Permissions',
    '使用情况、电池白名单、悬浮窗、无障碍、通知、自启动': 'Usage access, battery, overlay, accessibility, notification, autostart',
    '开机自动启动': 'Launch at startup',
    '登录 Windows 后自动在后台记录前台软件': 'Track foreground apps automatically after login',
    '本机': 'This device',
    '本机名称': 'Device name',
    '例如：我的手机 / 公司电脑': 'e.g. My phone / Work PC',
    '设备名称': 'Device name',
    '未同步': 'Not synced',
    '关于': 'About',
    '使用情况访问权限': 'Usage access',
    '读取应用使用时长的核心权限': 'Core permission to read app usage',
    '电池优化白名单': 'Battery whitelist',
    '防止后台统计被系统杀死': 'Prevents the system from killing tracking',
    '悬浮窗': 'Overlay',
    '达到限额时全屏遮挡提醒': 'Full-screen cover on limit',
    '无障碍服务': 'Accessibility',
    '达到限额时自动回到桌面': 'Go home on limit',
    '通知': 'Notifications',
    '显示后台统计常驻通知': 'Persistent tracking notification',
    '自启动（厂商设置）': 'Auto-start (OEM)',
    '小米/OPPO/vivo/华为等建议允许': 'Recommended on Xiaomi/OPPO/vivo/Huawei',
    '提示：受 Android 限制，普通应用无法强制关闭其他应用；限额功能通过': 'Note: due to Android limits, apps cannot force-close others; the limit feature works via ',
    '“全屏遮挡 + 回到桌面”实现，需要悬浮窗与无障碍权限。': 'full-screen cover + go-home, needing overlay & accessibility permissions.',
    '屏记 · 屏幕时间记录 v1.0.0\n': 'Screen Journal · Screen Time Tracker v1.0.0\n',
    '数据默认保存在本机；卸载应用 / 清除数据会丢失统计，请定期使用备份或 WebDAV 同步。\n': 'Data is stored locally; uninstalling or clearing data loses stats. Back up regularly via Backup or WebDAV.\n',
    '统计自安装本应用起永久保留，并可导入系统已有的历史记录。': 'Stats are kept permanently from installation, and system history can be imported.',
    // ---- WebDAV ----
    'WebDAV 服务器地址': 'WebDAV server URL',
    '例如 https://dav.example.com/user/ ': 'e.g. https://dav.example.com/user/ ',
    '用户名': 'Username',
    '密码 / 应用专用密码': 'Password / app password',
    '服务器上的同步目录': 'Sync folder on server',
    '用于在多设备中识别': 'Used to identify this device',
    '同步规则': 'Sync rules',
    '• 只同步应用使用时间统计，按“设备 + 天”增量合并，只增不覆盖、不删除\n': '• Syncs usage stats only, merged per device+day: additive, no overwrite, no delete\n',
    '• 分类、评分、描述、来源、限额等个人编辑不会同步\n': '• Personal edits (categories, ratings, notes, sources, limits) are not synced\n',
    '• 手动点击“立即同步”，不会自动同步\n': '• Sync is manual — tap "Sync now"; never automatic\n',
    '• 手机与电脑可登录同一个 WebDAV 账号互通': '• Phone and PC can share the same WebDAV account',
    '支持兼容标准 WebDAV 协议的网盘/自建服务（坚果云、群晖、Nextcloud 等）；': 'Works with standard WebDAV services (Jianguoyun, Synology, Nextcloud, etc.); ',
    '坚果云等需使用“应用密码”': 'Jianguoyun requires an app password',
    '夸克网盘等若未提供 WebDAV 地址，则不能直接用于同步，可改用其支持 WebDAV 的客户端中转。': 'Cloud drives without WebDAV URLs (e.g. Quark) cannot sync directly; use a WebDAV-capable client as relay.',
    '测试连接并立即同步': 'Test & sync now',
    '同步中…': 'Syncing…',
    '请先填写 WebDAV 服务器地址': 'Please fill in the WebDAV server URL first',
    '正在连接并同步…': 'Connecting & syncing…',
    // ---- 备份 ----
    '手动备份为完整备份，包含：\n': 'Full manual backup includes:\n',
    '• 全部应用的日 / 周 / 月 / 年 / 永久使用统计\n': '• All per-day usage stats (daily / weekly / monthly / yearly / lifetime)\n',
    '• 分类与多标签、评分、描述、软件来源\n': '• Categories & tags, ratings, notes, sources\n',
    '• 安装日期、每日限额、卸载/重装记录\n': '• Install dates, daily limits, uninstall/reinstall history\n',
    '备份文件用于长期归档或一次性迁移。': 'Backup files are for long-term archiving or one-time migration.',
    '导出完整备份文件（JSON）': 'Export full backup (JSON)',
    '导入备份（增量合并，不覆盖本地编辑）': 'Import backup (incremental merge, keeps local edits)',
    '覆盖恢复（清空当前数据后还原，危险）': 'Restore (wipe current data, dangerous)',
    '（WebDAV 同步仅同步统计数据，不含个人编辑）': '(WebDAV syncs stats only, not personal edits)',
    '建议：换机或重装 App 前先导出备份；多台设备日常统计推荐使用 WebDAV 同步，': 'Tip: export a backup before switching phones or reinstalling; for daily multi-device stats use WebDAV, ',
    '建议先导出一份当前备份。此操作不可撤销。': 'export a backup first. This cannot be undone.',
    '确认覆盖恢复？': 'Confirm restore?',
    '将清空本机全部应用、分类、统计与编辑内容，然后用备份文件还原。': 'This clears all apps, categories, stats and edits, then restores from the backup file.',
    '确认覆盖': 'Restore',
    // ---- 图表 / 通用组件 ----
    '0时': '0:00',
    '6时': '6:00',
    '12时': '12:00',
    '18时': '18:00',
    '24时': '24:00',
    // ---- 主题 / 语言 / 关于 ----
    '外观': 'Appearance',
    '主题模式': 'Theme',
    '跟随系统': 'System',
    '浅色': 'Light',
    '深色': 'Dark',
    '强调色': 'Accent color',
    '语言': 'Language',
    '中文': '中文',
    'English': 'English',
    '关于屏记': 'About',
    '版本': 'Version',
    'GitHub 开源': 'GitHub',
    '检查更新': 'Check for updates',
    '开源许可证': 'License',
    '赞赏支持': 'Support us',
    '项目主页与下载': 'Project page & downloads',
    '在浏览器中打开 GitHub 仓库，查看源码、Issue 与最新版本。': 'Open the GitHub repo in your browser for source code, issues and latest releases.',
    '前往 GitHub Releases 页检查是否有新版本。': 'Check the GitHub Releases page for new versions.',
    '本项目基于 MIT 许可证开源。': 'This project is open source under the MIT License.',
    '如果你喜欢屏记，可以请我喝杯咖啡支持继续开发。': 'If you like Screen Journal, consider buying me a coffee to support development.',
    '复制成功': 'Copied',
    '打开': 'Open',
    '复制链接': 'Copy link',
    '仓库地址即将发布': 'Repo link coming soon',
    '好的': 'OK',
    '自定义图标': 'Custom icon',
    '选择图片': 'Pick image',
    '清除': 'Clear',
    '裁剪图片': 'Crop image',
  };


  // ---- 动态模板 helper ----
  static String nApps(int n) =>
      lang == 'en' ? '$n apps' : '共 $n 个应用';
  static String nDays(int n) => lang == 'en' ? '$n d' : '$n 天';
  static String nStats(int n) => lang == 'en' ? '$n 条统计' : '$n 条统计';
  static String rating(int n) => lang == 'en' ? '$n/10' : '$n 分';
  static String since(String day) => lang == 'en' ? 'since $day' : '自 $day 起';
  static String importDone(int n) => lang == 'en'
      ? 'Import done, updated $n stats'
      : '导入完成，更新 $n 条统计';
  static String importResult(int cats, int apps, int days) => lang == 'en'
      ? 'Import done: $cats categories, $apps new apps, $days stats'
      : '导入完成：分类 $cats 个，新增应用 $apps 个，统计 $days 条';
  static String uncategorizedHint(int n) => lang == 'en'
      ? '$n apps not categorized yet (new apps go to Uncategorized)'
      : '有 $n 个应用尚未分类（新装应用会自动进入未分类）';
  static String importedDays(int n) => lang == 'en'
      ? 'Done: imported/updated $n daily stats (as far back as the system keeps)'
      : '完成：导入/更新了 $n 条按天统计（系统保留多久就能读多久）';
  static String lastSynced(String s) =>
      lang == 'en' ? 'Last synced: $s' : '上次成功同步：$s';
  static String deviceId(String id) =>
      lang == 'en' ? 'Device ID: $id' : '设备 ID：$id';

  static String t(String zh) => lang == 'en' ? (_en[zh] ?? zh) : zh;

  static String get appName => t('屏记');

  /// 周几标签：中文「周一」/ 英文「Mon」
  static String weekday(DateTime d) => weekdayIdx(d.weekday);

  static String weekdayIdx(int w) {
    if (lang == 'en') {
      const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return wd[w - 1];
    }
    return '周${'一二三四五六日'[w - 1]}';
  }

  /// 小时标签：中文「9时」/ 英文「9:00」
  static String hour(int h) => lang == 'en' ? '$h:00' : '$h时';

  /// 月份标签（图表横轴）：中文「3月」/ 英文「Mar」
  static String month(int m) {
    if (lang == 'en') {
      const ms = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return ms[m - 1];
    }
    return '$m月';
  }
}

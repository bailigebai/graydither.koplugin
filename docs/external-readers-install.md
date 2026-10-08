# 三插件灰度与全刷安装说明

2026-10-08。本轮设备测试版：GrayDither 0.3.0、MangaWeb 0.8.84、WebDAV漫画 0.4.16。三个安装包已完成软件检查。两个内置阅读器的灰度与自动全刷均默认关闭，可分别开启、关闭，设置互不影响。下载对应[GrayDither](https://github.com/bailigebai/graydither.koplugin/releases/tag/v0.3.0)、[MangaWeb](https://github.com/bailigebai/mangaweb.koplugin/releases/tag/v0.8.84)、[WebDAV漫画](https://github.com/bailigebai/webdavmanga.koplugin/releases/tag/v0.4.16)的Release附件。

## 安装三个插件

1. 完全退出KOReader，在电脑备份现有的三个插件文件夹及KOReader设置目录。
2. 分别解压graydither-0.3.0.zip、mangaweb-0.8.84.zip、webdavmanga-0.4.16.zip，得到三个.koplugin文件夹。
3. 将三个文件夹复制到当前KOReader数据目录的plugins里。覆盖程序文件时保留原缓存、用户数据及KOReader设置目录，不要删除后重新安装。
4. 确认路径以plugins/graydither.koplugin/main.lua、plugins/mangaweb.koplugin/main.lua和plugins/webdavmanga.koplugin/main.lua结束，不能多套一层目录。
5. 启动KOReader，在插件管理中启用三个插件。安装或启用后完全退出并重新启动。

Kindle常见目录为USB根目录的koreader/plugins；Android常见为/sdcard/koreader/plugins，实际以自己的KOReader数据目录为准。鸿蒙设备需要先能正常运行KOReader并访问该目录；本版没有HarmonyOS NEXT原生HAP安装包，未验证鸿蒙兼容层。

如果设备此前已安装原全刷补丁2-eink-full-refresh.lua，退出KOReader后先备份，再把它移出patches目录，避免两个自动全刷同时运行。无需修改电脑上的原插件材料。

只更新GrayDither，旧版两个阅读器不会出现新设置入口。MangaWeb原有授权流程保留，使用已授权阅读入口即可。

## 打开与关闭

MangaWeb：进入漫画正文，打开“设置 → 灰度与全刷”。

WebDAV漫画：进入漫画正文，点击画面中间，在阅读菜单选择“灰度抖动与墨水屏刷新”。

在共同设置页中：

- “启用漫画灰度抖动”控制正文灰度，首次未勾选。
- “墨水屏刷新 → 启用自动全刷”控制自动刷新，首次未勾选。
- 自动间隔为1～50次新画面，默认5；先用默认“原生全刷”。
- “立即全刷”会先返回正文再刷新，自动开关关闭时也可手动使用。
- 可选“黑白辅助”，两种纯色各保持0.10～1.00秒，默认0.30秒。

退出重开后保留各自选择。缺少或禁用GrayDither时，两个漫画阅读器仍按原方式阅读，设置入口会提示服务不可用。

WebDAV由新自动全刷接管期间，临时停止原每页全刷和页动画；原设置值保留，关闭新功能或服务不可用时恢复。

## 最简单的验收

1. 分别进入两个阅读器，确认灰度和自动全刷首次都关闭，正常显示漫画。
2. 只开启MangaWeb灰度，对同一张图开关比较，再检查WebDAV仍关闭；反向再测一次。退出重开，确认各自设置保留。
3. 单独开启自动全刷，把间隔设为2。第一屏建立基准，显示第2个、第3个不同画面后应请求一次全刷；同屏重绘不计数。灰度关闭时自动全刷也能单独工作。
4. 打开设置、返回同一正文，应重新建立基准；慢加载下一张图时旧正文维持灰度、暂停刷新，成功显示后继续累计。
5. 在源插件已有的分片、平移、长条或分格模式试翻页。黑白阶段退出或休眠，返回后不应有旧覆盖或迟到闪屏。
6. 分别关闭灰度和自动全刷，再检查原图片阅读及WebDAV原刷新/动画策略恢复。

发现问题时记录设备型号、系统与KOReader版本、来源插件、阅读模式、两个开关状态及复现步骤；保留KOReader日志即可定位。

## 已检查与待验收

GrayDither 106项检查、MangaWeb 40组规格、WebDAV 193组规格及687项真实正文联测通过；最终安装包解压文件也已检查，新上下文独立审查和全部文件逐字节核对通过。测试未访问真实漫画网站、私人WebDAV或设备。

这里的“256阶”是256个输入亮度经过软件抖动映射为16个输出灰阶，不会改变屏幕硬件。Kindle、Android和鸿蒙实机画质、触摸、真实波形、残影、速度、内存及耗电仍需安装后验收。

## 琪琪市场

在“qiqi 应用商店”联网点击“刷新缓存”，按graydither、mangaweb、webdavmanga查找并选择上述对应版本的插件ZIP。市场读取bailigebai账号下的公开.koplugin仓库和Release，无需新增收录名单。若还显示旧版本，先确认联网后再刷新缓存。

已经安装旧版时，可进入市场更新管理，点“检查所有更新”。附件列表也会显示.sha256校验文件，安装应选择对应.zip；若项目说明仍旧，可在市场设置清理README缓存再重新打开。

graydither-test.cbz是测试漫画，sample-preview.png是预览图，两者不是插件安装包。manifest.json记录三个安装包及测试素材的SHA-256校验值。

# 内置漫画阅读器兼容版验收

2026-10-08。本轮采用已批准的共用核心方案。当前为本地设备测试包：GrayDither 0.3.0、MangaWeb 0.8.84、WebDAV漫画0.4.16。未安装设备、未发布这三个新版本，也未访问真实漫画网站或用户的WebDAV。

## 实际改动

GrayDither支持在文件管理器提供服务，新增正文实例绘制管道和独立阅读会话；复用已有算法、参数校验与刷新器。源阅读器通过官方PluginLoader能力探测，从自己的reader配置提供设置、正文窗口、成功绘制屏标识及生命周期。缺服务保持原阅读。两个来源的灰度与自动全刷均默认false，互不影响且不继承宿主全局开关。

只改变正文图像区域，不改变共享原图、预加载缓存、Screen抖动标记或全局UI类。正文继续按源阅读器缩放/合成/夜间处理，私有缓冲完成FS后回写。短暂加载暂停全刷和计数并保留成功屏进度及正文灰度；设置/休眠重建基准。WebDAV额外刷新接管时暂时停用原每页全刷/动画，偏好保留；当前帧能力失败也恢复原策略。

## 证据与复跑

GrayDither源码及最终ZIP解包均106项通过，10个运行Lua可编译；固定官方ImageWidget合同14项、真实UIManager与ImageWidget会话合同5项。算法、原生文档和既有刷新回归全部保留。

```text
python scripts/run_tests.py
python scripts/run_tests.py --plugin-root ./extracted/graydither.koplugin
```

MangaWeb本仓库全部10组（含真实共用核心）、78个Lua语法通过；另30组既有纯合成基线合计40组通过，安装包解包同40组及67个产品Lua通过。打包4项、测试入口3项通过。完整源证据与参数见对应仓库docs/graydither-verification.md。

```text
python spec/run_lua_specs.py --graydither-root ../gray
python spec/run_lua_specs.py --graydither-root ../gray --plugin-root ./extracted/mangaweb.koplugin
```

WebDAV原主线192组/107Lua基线通过，接入版本源码与最终安装包各193组/108运行Lua通过；真实正文联测各687项检查通过。完整参数见对应仓库docs/graydither-integration.md。正文联测使用实际Reader、Shell、PanelSession、WebtoonSession和GrayDither；固定官方ImageWidget/BlitBuffer保持原样，CBB关闭。

```text
python scripts/run_lua_specs.py --all --syntax-root webdavmanga.koplugin
python scripts/run_lua_specs.py --all --plugin-root ./extracted/webdavmanga.koplugin --syntax-root ./extracted/webdavmanga.koplugin
python scripts/run_graydither_contract.py --gray-root ../gray --plugin-root ./extracted/webdavmanga.koplugin --gray-plugin-root ../gray-extracted/graydither.koplugin
```

已有象限宿主测试需KOREADER_FRONTEND指向官方frontend。本轮现成宿主的ImageWidget与固定646b2e39源码字节一致。测试仅使用合成图像、测试配置和假下载，没有执行真实授权。开发依赖为Python3.11/Lupa2.8，不进入安装包。

## 独立审查与修复

以新上下文只读审查三仓库，问题均先失败复现再修复：

- 私有目标复裁剪使正半像素居中少画一列；按宿主规则floor目的坐标，并保留异常小数裁剪的原路径。
- 夜间私有全宽BB的Lua反色路径遇64位size_t；局部目标使用宿主invertblitFrom同等反色，不修改fixture或全局设置。
- MangaWeb旧reader配置缺少新增开关时，默认false被and/or表达式丢失，导致所有保存失败；显式分支保持false，覆盖旧配置升级及两个开关独立保存。
- 来源store保存失败返回false被公共设置忽略；新适配边界转为错误，旧来源接口语义保留，并在公共状态菜单提供错误说明。
- 一次菜单/Spin关闭失败留下模态窗口；受控重试一次，已关闭会话仍能重试残留清理。
- WebDAV分格同序号的pan/zoom漏计，且旧相机提交晚于回调；传递实际成功渲染选项，失败不产生新标识。
- attach失败的当前帧丢失源full策略；最终正文发布后复核接管，失败当帧恢复原策略。
- 宿主直接关闭正文窗口后黑白阶段继续；来源CloseWidget清理和公共isWidgetShown守卫取消旧任务。
- 保留旧正文下载、page到page恢复及长条直接next入口遗漏暂停；实际加载入口pause(true)，成功正文幂等恢复，首末页无渲染不暂停。
- 暂停刷新不应把保留的旧正文切回原图；独立灰度开关继续生效，暂停只阻止计数和刷新。

最终独立复查未发现本范围剩余功能阻塞。原WebDAV CRC性能规格曾在主机并行负载下超过既有3秒预算；阈值和实现没有改变，原主线及最终完整重跑通过。两项既有解包测试错误地从安装目录找开发夹具，测试根与产品根已分开，夹具不进入设备包。

## 包内容与校验

GrayDither严格13文件：10Lua及README/LICENSE/THIRD_PARTY；MangaWeb严格71文件；WebDAV严格124文件且原官方native库不变。三个包均检查单一.koplugin根、CRC、SHA256及每项源字节；源码测试和安装包模块分开选择，防止只测工作树却交付旧文件。

本次GrayDither最终包36996字节，SHA256 `83af3565a093b388e5bca832d2be957e014449685998d435cfb6ca88ad011cb1`；三包完整清单以统一交付目录的manifest.json为准。原公开0.2.0及此前回退包未被覆盖。

## 用户验收与未覆盖范围

同时覆盖三个插件文件夹，完全退出重启KOReader并启用插件。在两个来源各自的阅读设置里打开“灰度与全刷”，先确认两个开关未勾选；仅开启一个来源，另一个保持关闭。比较同图开关灰度的变化，重开后确认偏好保存。

自动间隔设2：首次不计，重复重绘不计，第2次不同成功正文屏请求刷新。慢加载期间保留旧正文、不闪屏；设置期间不自动刷新。试分格pan/zoom、长条跨图，再分别关闭灰度与自动全刷。手动全刷应先返回正文；黑/白阶段退出或休眠后不得残留覆盖。

未验证Kindle/Android/鸿蒙实机、真实C blitter/ABI、MuPDF原生缩放滤镜、触摸、光学灰阶、全刷波形、CPU/峰值内存、残影和耗电。软件256输入→16输出灰阶不等于硬件256灰阶。宿主能正常运行KOReader才可安装，HarmonyOS NEXT不提供HAP；本地通过不作为全设备兼容认证。

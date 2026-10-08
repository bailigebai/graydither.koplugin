# 0.2.0 全刷整合验证记录

日期：2026-10-08。当前结果：全刷核心能力已独立整合进graydither.koplugin，生成0.2.0设备测试包；未安装设备或远端发布。0.1.0 ZIP保留，灰度算法、pipeline和原灰度设置模块与0.1.0包逐字节一致。

本文件记录公开发布前的功能验收；后续GitHub发布、重新打包及市场检查记录见publish-verification.md。

## 改动与范围

新增refreshsettings.lua、refresh.lua、refreshmenu.lua；main.lua只接入普通插件菜单与PageUpdate/PosUpdate、ReaderReady、关闭、休眠/恢复、旋转/尺寸事件，版本元数据更新。没有全局覆盖ReaderUI、ReaderMenu、MenuSorter或UIManager。

支持手动全刷、自动开关、1～50整数间隔和黑白各阶段0.10～1.00秒保持。自动默认关闭，间隔默认5、保持默认0.30秒，native默认、flash可选；关闭再开保留所选间隔。刷新独立用于当前阅读文档，灰度仍限CBZ／CBR普通MuPDF绘制。

每次不同有效页码算一次页面变化，首次及重复同页不计数，跳页算一次。手动完成后自动计数清零。任务互斥、取消和代次检查防止陈旧回调影响下一本书；滚动期间到期只保留一个0.25秒正延时重试，停止后执行，窗口遮挡则等待后续页面更新。

宿主原有刷新策略继续有效，本插件自动开关只控制额外请求；不改full_refresh_count、夜间模式、硬件抖动或驱动物理波形。

## 验证证据

最终源代码完整检查及最终ZIP解压安装代码检查均exit code 0，68项通过，8个产品Lua文件编译通过：

| 套件 | 数量 | 证据 |
|---|---:|---|
| algorithm_spec.lua | 10 | 原灰度黄金值、均值、stride/alpha与重复输出 |
| pipeline_spec.lua | 16 | 原缓存、返回值、包装、错误释放及192裁剪/192居中组合 |
| settings_spec.lua | 6 | 原全局/单书优先级和设置保护 |
| kopt_contract_spec.lua | 1 | 原8种夜间路径组合 |
| refreshsettings_spec.lua | 5 | 默认、整数/范围/NaN/inf、持久保存、不改宿主键 |
| refresh_spec.lua | 15 | 去重、互斥、黑白保持、取消、失败恢复、过期回调、尺寸变化、滚动停止重试 |
| refresh_contract_spec.lua | 4 | 真实UIManager/Widget/Event/Geom，及真实ReaderRolling松手方法 |
| plugin_spec.lua | 11 | 菜单回调、PDF独立刷新、初页时序、EPUB滚动、Android暂停、旋转、非法输入提示 |
| 合计 | 68 | 全部通过 |

环境：现有Python 3.11/Lupa LuaJIT21，LuaJIT 2.1.1774896198；没有安装新依赖。固定KOReader提交646b2e39e24a899016d38ef6dc47e3f7c429c8ba、base子模块9e9befc73f494556e2ff0732940e84fa9d0b6dac。第三方源码原样保留，测试前校验provenance.json里的SHA-256；fixture不进入设备ZIP。

真实FFI内存与BlitBuffer参与绘制；UIManager调度、显示、取消、全刷提交和事件传播使用真实固定源码。Screen、驱动提交记录、时钟和MuPDF/CRE解码仍为替身。ReaderRolling只加载未经改写的onPanRelease方法，未启动整个阅读器。

复跑命令：

```powershell
python scripts/run_tests.py
python scripts/run_tests.py --plugin-root .test-output/unpacked-0.2.0/graydither.koplugin
```

## 独立审查与修正

新上下文只读审查先复跑64项，找到三项问题；全部由本代理写失败复现后最小修复，最后完整68项通过：

1. 原暂缓策略依赖松手后的新页事件，真实ReaderRolling不发送，连续拖动可能永不自动刷新。新增可取消的0.25秒重试，使用真实松手方法和真实UIManager队列验证，无需伪造PosUpdate。
2. NumberPicker文本输入允许小数，直接调用严格setInterval会抛错。菜单先提示“请输入1～50的整数页数”，保留原设置，回调不抛异常。
3. 取消时第一次close失败会留下模态遮罩。增加一次同步有限重试，黑白两阶段的失败注入都移除覆盖层，且不遗留任务。若宿主close持续失效，仍只能记录并保留引用以供后续清理，不据此承诺永久宿主错误下可恢复。

滚动重试的决定记录在progress.md：有到期任务且持续滚动时，每秒最多约4次轻量检查；没有任务时不轮询。实际耗电仍待设备验证。没有遗留审查要求的功能修正。

## 产物

ZIP根目录graydither.koplugin/，共11个文件（8个Lua及README、LICENSE、THIRD_PARTY），逐文件与源代码字节比对一致，CRC通过。无测试脚本、fixture或额外原生库。CBZ含3页800×1200灰度PNG。

| 文件 | 字节 | SHA-256 |
|---|---:|---|
| graydither-0.2.0.zip | 29929 | c47913b5fba7b42445c531cd0a018e1bff4517d5c277a17da0303acffd6f8997 |
| graydither-test.cbz | 57717 | 5642e45337701ff2708e447cd32613b70a8ec0648bd4eae149a49b45d7ad3708 |
| 保留的graydither-0.1.0.zip | 22729 | 54fca6e90c96cd3482d3a426bc1858dbfbbfc98b991e246fa7336c774b1ad0b3 |

以上为公开发布前的功能验收包。当前产物清单为dist/manifest.json，重新打包会更新hash；GitHub附件hash以publish-verification.md为准。

输入原文件未修改：2-eink-full-refresh.lua的SHA-256为26f0dd77d0630ec2c0b857b8d9348d146e0cc1ac0e042304a0d7a27d9f2caa5d；安装说明.txt为8830dd856aea2a587d39cf5ad16309003fe26ad72c5a531a99fbc5ff9b142b18。来源作者与许可情况见THIRD_PARTY，不复制原代码或二维码进AGPL包。

## 最简单验收与未验证项

解压0.2.0 ZIP到实际KOReader数据目录的plugins，覆盖现有graydither.koplugin后重启。已安装旧全刷补丁的设备需由用户退出阅读器后将旧2-eink-full-refresh.lua移出patches，避免重复触发。

打开验收漫画，在“墨水屏刷新”先试立即全刷；分别选择原生、黑白辅助，确认结束后显示阅读画面。设间隔3并开启自动，初始页不计数，第3次页码变化应请求刷新；在3页漫画中可反向翻页完成第三次变化。关闭再开应保留间隔。再试PDF/EPUB独立刷新、连续拖动松手、同页重复刷新、快速连翻、关书/休眠/旋转，以及原灰度开关。

尚未验证真机型号/系统/KOReader版本、实际屏幕波形与光学保持时间、Kindle/Android厂商刷新接口、残影/速度/内存/耗电、原生CBB和完整UI数字输入。Android brokenLifecycle机型可能没有正常暂停/恢复广播，需实机核对。鸿蒙APK兼容设备与NEXT原生环境需分别确认；没有提供HAP。

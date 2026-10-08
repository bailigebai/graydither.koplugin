# 执行记录

计划：docs/superpowers/plans/2026-10-07-graydither-plan.md。

2026-10-07：用户“开始”承接已有B方案及临时规划；最小范围CBZ/CBR，设备信息可独立补充。根目录不是Git仓库，本项目使用新的独立目录隔离。

预检：Task1算法提供apply→Task2消费；Task2 controller和支持原因→Task3消费；Task3设置→菜单消费。接口一致。Task4只读取产品与测试，不修改其他项目。

决策：采用BB8/RGB32匹配宿主tile，避开native invert类型不匹配；代价是未知/Kopt优化模式回退原图。设备测试缺失不阻止本地实现，交付标记设备测试版。

Task1：complete。先观察Algorithm缺失的失败，再实现；固定base使用模块函数BB.tostring而非方法bb:tostring，已以真实源码纠正测试接口。algorithm_spec 10项通过，产品算法Lua可编译。固定灰51不变、黄金2x2、固定均值、alpha/stride和20次原图复制一致验证通过。

Task2：complete。Pipeline缺失失败已观察后实现；真实Document.drawPage/DrawPageInverted及BlitBuffer合同用例通过。异常释放断言依据真实getAllocated()==0，free并不清空data指针，测试禁止解引用释放后的指针。完整21项通过；BB8/RGB32 × 4旋转 × 2反色 × 2夜间共32合同组合包括负整数目标坐标。新增边界：非整数/scaled_rect/未知target绕过。设置采用宿主G_reader_settings命名键而非独立文件，减少文件与序列化职责；此变更将在Task3中落实。

Task3：complete。Settings/main缺失的失败已观察；设置6项、菜单生命周期6项通过。完整33项通过，5个产品Lua编译通过。单书强制开在全局关状态下实际处理页计数为1；当前文档包装不会碰宿主共享类。新偏好与宿主全局/文档设置一起保存，没有新增路径序列化。

独立审查发现裁剪未绘制背景被量化；已补2个失败复现（背景变化、真实tile类型矛盾），修正后完整35项通过。处理前从renderPage查询真实缓存tile格式及交集，仅在私有scratch的实际绘制viewport内处理；不包装/改变renderPage，不修改/释放缓存。代价为每次已启用绘制额外一次宿主缓存查询；解决背景改变与native反色源类型推断不足问题。

补充跨格式审查发现BB8临时缓冲往返会把RGB32未绘制背景灰度化；192组合矩阵在修复前明确失败（source BB8/target RGB32，部分裁剪）。改为仅回写实际绘制交集并去掉背景往返转换，矩阵和完整套件重新验证。原生CBB仍未测试，不能把此矩阵称为实机通过。

最终几何核对：ReaderView居中offset会产生.5，普通适页也可能被原整数guard绕过。新增小数居中用例明确失败（成功处理次数0而非1），再允许完整落在target内的非负有限小数目的坐标，按BlitBuffer.checkBounds规则floor偏移。源区域仍保持整数；负小数和目标裁剪小数保持原函数参数直通。192个居中组合、683×1024页面在758×1024屏幕上x=37.5的例子及四个风险位置回退通过，完整39项通过。

Task4：complete。独立审查与修复记录见verification.md；安装ZIP、三页验收CBZ及hash清单已生成。源项目及ZIP解压后代码均执行完整39项检查，5个产品Lua编译通过；ZIP内容逐文件与源代码比对、CRC与根目录核对通过。保留独立本地项目及feature/graydither-mvp分支，不安装、不推送、不发布。真机画质、性能、原生CBB和平台兼容性仍待设备验收。

2026-10-08全刷整合：Spec/Plan为2026-10-08-refresh-design.md和refresh-plan.md。预检：配置get*/set*→控制器及菜单；控制器生命周期→main事件；菜单build→main普通注册，接口一致。输入原文件保持不动，功能独立实现；原作者归属记录在来源说明。继续原独立目录，git无HEAD，保留0.1.0 ZIP作为回退。

刷新Task1：complete。refreshsettings模块缺失的失败已观察；默认、配置范围/NaN/inf拒绝、关闭再开保留间隔及既有设置保留均通过。完整44项通过，6个产品Lua可编译。配置命名graydither_refresh_*，不读取/改写原补丁的eink_refresh_*。

刷新Task2：complete。refresh控制器缺失失败已观察；13项控制器用例、3项固定真实UIManager合同用例通过。屏幕尺寸变化的失败复现后改为每次paint查询当前尺寸。完整60项通过，7个产品Lua可编译。native请求、black/white/full恢复、计数与去重、待执行/黑/白阶段取消、暂停恢复、错误恢复和陈旧回调全部覆盖。原生CBB和物理屏幕仍不在本地验证范围。

刷新Task3：complete。新增菜单缺失失败已观察；10项菜单/lifecycle用例通过，其中初始页早于ReaderReady、PDF独立刷新、滚动PosUpdate、Android RequestSuspend和旋转尺寸事件均被实际插件方法覆盖，不返回true吞其他插件事件。完整64项通过，8个产品Lua可编译。宿主滚动会降级full为fast，因此滚动时保留到期计数不提交全刷，后续页面更新再尝试；不改宿主滚动标志。

刷新最终审查：独立64项复跑通过，识别三项问题，均完成失败复现→最小修复→全套通过。Final fixed 1：真实拖动松手不再发PosUpdate，原策略会永不刷新；改为仅一个0.25秒正延时可取消重试，真实ReaderRolling松手+UIManager队列合同通过。Final fixed 2：NumberPicker可输入小数，菜单回调不应让设置断言抛出；增加输入提示，保持旧间隔。Final fixed 3：取消时close第一次失败会留下覆盖层；同步有限重试一次，第一/第二纯色阶段故障注入都恢复阅读窗口。

Ruling：滚动到期等待从“等后续页更新”改为0.25秒间隔的单任务重试——真实宿主不发结束通知，原方案不能满足滚动阅读自动全刷——代价为有待刷新且持续滚动时每秒最多约4次检查；耗电仍需实机测试。菜单遮挡仍等待后续页面更新，不覆盖对话框。

刷新Task4：complete。最终68项完整检查通过，8个产品Lua编译通过；新安装ZIP解压后执行同一套检查。原0.1.0 ZIP、核心算法/pipeline/settings保持，输入桌面原文件未修改。产物hash及固定源码、独立审查修复、安装验收范围见docs/refresh-verification.md。不安装、不发布、不推送，保留现有本地项目。

2026-10-08独立发布：用户追加明确授权公开GitHub发布及琪琪市场发现。采用公开独立仓库+版本ZIP，main首次提交e17723f；GitHub仓库bailigebai/graydither.koplugin和v0.2.0 Release已上线。仅补发布元数据、安装/开发说明、公共路径与Git换行规则，灰度/刷新行为不改。琪琪市场按该账号公开.koplugin仓库动态发现，无需更改市场。源代码、Git候选导出、ZIP以及重新下载远端ZIP均68项通过，8Lua编译，独立发布审查放行。四项远端附件均与本地字节一致；详见publish-verification.md。设备安装仍由用户验收。

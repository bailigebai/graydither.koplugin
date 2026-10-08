# 全刷整合实施规划

> 执行：superpowers:executing-plans，本代理分阶段实现；独立代理只读核查输入、宿主合同和最终审查。

**Goal:** 将全刷核心能力整合进现有插件，交付0.2.0设备测试版。
**Architecture:** 刷新配置、控制器、菜单各自独立，main负责事件转交；保持灰度绘制算法不变。
**Tech Stack:** KOReader LuaJIT、现有UIManager/Widget/SpinWidget，Python/Lupa本地检查；无新增设备依赖。
**Spec:** docs/superpowers/specs/2026-10-08-refresh-design.md。

## 约束

自动默认关闭，间隔默认5、范围1～50整数，保持默认0.30秒、范围0.10～1.00秒，native默认、flash可选。设置只用graydither_refresh_*命名键。计数按不同页码的变化，首次为基线。只改本独立项目，不修改输入原文件，不安装、推送或发布。不复制无许可输入代码或二维码。

当前git尚无HEAD、全部0.1.0源码为本任务生成的未提交文件；继续使用现有独立项目目录及保留的0.1.0 ZIP作回退，不新建需要基准提交的worktree，也不更改用户身份配置。修改前完整39项检查通过。

## 阶段1：配置

文件：新增graydither.koplugin/graydither/refreshsettings.lua、tests/refreshsettings_spec.lua。
接口：RefreshSettings.new(store)，getEnabled/getInterval/getMode/getHold、setEnabled/setInterval/setMode/setHold。
- [x] 写失败用例：无配置默认、关闭再启用保留间隔、非法存值fallback、1/50与.10/1边界、写入拒绝NaN/inf/小数间隔。
- [x] 运行观察功能缺失失败，再最小实现配置；运行全套通过。

## 阶段2：刷新控制器

文件：新增graydither.koplugin/graydither/refresh.lua、tests/refresh_spec.lua、tests/refresh_test_support.lua；必要固定上游UIManager fixture和tests/refresh_contract_spec.lua。
接口：Refresh.new(reader_ui,prefs,on_error)，start/pageUpdate/request/stop/suspend/resume/reset/cancel；实例状态count/completed/busy/last_error。消费者只使用这些公开生命周期方法。
- [x] 写失败用例：重复PageUpdate不算页，3次不同页面仅触发1次；快速更新只排一项。
- [x] 原生full及黑白两阶段按时间恢复；手动清零自动计数；菜单遮挡延后。
- [x] 待执行/黑/白阶段stop、suspend、reset取消；过期callback不重启；错误恢复后能重试。
- [x] 最小实现，使用同一个可取消回调、代次和实例覆盖层；运行控制器及全套检查。
- [x] 对已确认宿主方法做窄合同检查，记录CBB/真实设备未测。

## 阶段3：菜单与事件

文件：新增graydither.koplugin/graydither/refreshmenu.lua；修改main.lua、_meta.lua、tests/plugin_spec.lua并添加需要的菜单用例。
接口：RefreshMenu.build(controller,prefs)->菜单项，main注册menu_items.graydither_refresh，sorting_hint=more_tools。灰度与刷新各自配置，PDF/EPUB不被灰度guard阻止刷新。
- [x] 菜单callback/SpinWidget确认先测失败；测试ReaderReady/PageUpdate/关闭/休眠/恢复/旋转转交，不返回true。
- [x] 实现菜单和转交；设备测试版0.2.0元数据；运行全套。

## 阶段4：审查与交付

文件：README.md、THIRD_PARTY.md、docs/refresh-verification.md、docs/progress.md；打包脚本沿用版本读取和内容同步。
- [x] 新上下文审查整个刷新功能；重要缺陷先失败复现再修正。
- [x] 全套、全部产品Lua编译、ZIP逐文件比对、CRC和hash；解压安装包再跑全套。
- [x] 更新说明、能力来源、关闭/回退方式和真机验收步骤；保留0.1.0与新增0.2.0 ZIP。

## 审查重点

1. 初始PageUpdate可能早于ReaderReady，初始页不应算翻页（阶段2/3）。
2. 同轮多次翻页、手动与自动叠加不产生多个遮罩（阶段2）。
3. 关闭/休眠/旋转后残留callback不污染新书（阶段2/3）。
4. 损坏配置不能造成忙循环或超长遮挡（阶段1/2）。
5. 显示/重绘/关闭失败不会永久busy，覆盖层应尽力移除并允许重试（阶段2）。

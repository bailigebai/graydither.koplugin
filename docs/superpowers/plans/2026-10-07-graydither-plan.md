# 漫画灰度抖动插件实现计划

Spec: docs/superpowers/specs/2026-10-07-graydither-design.md
目标：完成0.1.0可安装设备测试版。所有产品改动限本独立仓库。执行方式：本代理实现，其他代理只读核对源码与最终独立审查。无需安装依赖。

## 全局约束

沿用设计定义的CBZ/CBR范围、BB8/RGB32缓冲、FS规则和8 Mi像素/8192维度限制。宿主已有gamma、缩放、反色、硬件波形不做设置改动。源码验证版本KOReader 646b2e39e24a899016d38ef6dc47e3f7c429c8ba、base 9e9befc73f494556e2ff0732940e84fa9d0b6dac。测试依赖作为带许可的固定源码fixture，不进入设备安装包。

## Task 1：测试环境与算法

文件：scripts/run_tests.py、tests/algorithm_spec.lua、graydither.koplugin/graydither/algorithm.lua、tests/fixtures。
接口：Algorithm.apply(bb) -> true，或nil, reason；仅改变自己拥有的BB8/RGB32。
步骤：
- 写测试并运行，明确因缺少Algorithm功能失败。
- 黄金2x2、量化灰阶不变、固定均值、RGB32灰51、alpha/stride守护、尺寸/旋转/inverse拒绝。
- 用真实上游BlitBuffer运行，实现精确亮度及两行浮点FS。
- 全套验证，再记录证据。

## Task 2：文档页面接入

文件：graydither.koplugin/graydither/pipeline.lua、tests/pipeline_spec.lua。
接口：Pipeline.supportReason(doc) -> nil或reason；Pipeline.attach(doc,is_enabled,on_error) -> controller或nil,reason；controller:detach()。
消费Algorithm.apply；使用真实BlitBuffer。实例drawPage wrapper捕获原函数。
步骤：
- 测试先失败：关闭直通、开启独立缓冲、源缓存不变、重复20次输出稳定、参数与区域保持、SW恢复、错误回退。
- 测试后安装第三方包装再detach，不覆盖第三方；同时attach/detach幂等。
- 检查灰度/彩色格式与配置 guard；拒绝未知类型和超限，失败不分配。
- 将固定Document源码作为合同测试fixture，观察裁剪/反色行为。
- 实现并运行全套。

## Task 3：设置与菜单

文件：graydither.koplugin/graydither/settings.lua、graydither.koplugin/main.lua、_meta.lua、tests/settings_spec.lua、tests/plugin_spec.lua。
接口：Settings.new(global_store,doc_store)，isEnabled/getOverride/setOverride/setGlobal；单书/全局作用域分别使用key graydither_enabled，全局复用G_reader_settings。
步骤：
- 先测全局关+单书开、全局开+单书关、nil跟随、非法值安全处理。
- main初始化注册菜单，ReaderReady使用self.ui.document和doc_settings；CloseDocument不返回true。
- 设置改变立即重画，状态显示绕过条件与处理失败；不覆盖用户的宿主设置。
- 测试生命周期与菜单callback真实调用本插件方法，运行全套。

## Task 4：交付、独立审查与验收

文件：README.md、graydither.koplugin/README.md、LICENSE、THIRD_PARTY.md、scripts/package.py、docs/verification.md。
步骤：
- 编译/加载全部产品Lua，执行完整测试。
- 新上下文独立审查输入边界、原生退出风险、释放、单书开关、插件包装共存。
- 必要修正先写复现失败测试再修复；最终完整测试通过。
- 构建dist/graydither-0.1.0.zip和dist/graydither-test.cbz，核对ZIP根路径和解压后内容，记录hash。
- README写明菜单、安装路径、已测与未测范围；提供关闭/卸载方法。
- 保留本地代码，不发布/推送/安装设备。

## Review Focus

1. document.sw_dithering原本nil时也必须恢复nil；异常路径同样恢复。
2. host可能使用RGB32夜间反色：scratch类型与实际tile一致，未知color_bb_type绕过，不能依赖pcall兜native exit。
3. 其他插件后装包装仍委托本插件时，detach后的残留包装不能再处理。
4. Rect的负坐标、部分裁剪与旋转目标不能写出区域，必须由真实BlitBuffer及固定Document合同检查覆盖。
5. 关闭默认全局后，单书强制开启必须在下一次绘制真正执行，不只是状态显示开启。

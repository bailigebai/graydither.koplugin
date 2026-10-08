# 外部漫画阅读器接入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Steps use checkbox syntax.

**Goal:** MangaWeb和WebDAV漫画的内置阅读器能分别启闭灰度及自动全刷，两个开关默认false，集中使用GrayDither核心。

**Architecture:** GrayDither为当前阅读窗口创建可选会话。会话仅包装正文ImageWidget实例、使用私有图像区域缓冲、接收成功可见绘制的逻辑屏标识。源阅读器保留自己的设置及生命周期，缺少服务时原路径继续工作。

**Tech Stack:** 现有Lua 5.1/LuaJIT、KOReader BlitBuffer/ImageWidget/UIManager、Python 3.11/Lupa 2.8开发检查；不新增设备依赖。

**Spec:** docs/superpowers/specs/2026-10-08-external-readers-design.md（用户2026-10-08确认计划并要求开始）。

## Global Constraints

- 两插件各自保存graydither_enabled、graydither_refresh_enabled，未设置均false；不得继承全局开关。
- 刷新间隔1～50、默认5；native默认、flash可选；保持0.10～1.00秒、默认0.30秒。参数用源store适配复用现有校验。
- FS只处理私有正文区域，保留原缓存、alpha、夜间、旋转和背景；8192边长／8 Mi像素限制。
- 不覆盖全局ImageWidget、UIManager或Screen标记；关闭、暂停、设置和加载／错误时取消未完成刷新。
- 首屏、重复重绘、预加载和UI变化不计数；按实际成功可见阅读屏计数。
- 灰服务实际管理自动刷新时WebDAV临时停用原每页全刷与动画，原偏好保留；服务失效或关闭恢复旧策略。
- 工作树：gray、mangaweb、webdav位于本项目ignored的.test-output/compat-work；不得改原桌面补丁、设备或其他工作树。

## Review Focus

1. 模态设置或同窗口嵌入设置：图片没有可见时不能计数／闪屏（Task2-4）。
2. 原缓冲复用、透明背景、软件抖动、负偏移和旋转：重复绘制输出不漂移（Task1）。
3. 首次false与设置写入失败：不能被已有全局true打开，失败保留原路径（Task2-4）。
4. 快速切读者、关窗、禁用插件、黑白阶段退出：旧回调不能覆盖新读者（Task2-4）。
5. 长图／分片／分格复用图片index：成功逻辑屏变化计数，设置重绘不重复计数（Task3-4）。

## 接口契约（三个任务共用）

`GrayDither:createImageSession(options) -> session`：options.owner是真实窗口；options.store是readSetting/saveSetting/delSetting接口，所有graydither_*键保存在源插件独立偏好；options.is_ready()返回正文可见且非设置／加载／错误；options.redraw()请求源窗口重绘。源端必须pcall并检测能力，失败可无session继续阅读。

会话字段：`preferences`为现有Settings，`refresh_preferences`为现有RefreshSettings，`refresher`为Refresh。方法：

- `attachImage(widget, token)`：token为当前会话内稳定字符串，不含凭据；仅包装该实例。每次正文重建或模型更新重新调用，同实例可更新token。
- `settingsChanged()`：取消流程、重建计数基准并重绘；写入操作先成功保存再调用。
- `pause(preserve_progress)`：取消、停止计数；默认false重建首屏基准，短暂加载用true保留成功屏的token及计数。`resume()`按该暂停状态恢复；`reset()`取消并重建基准；`close()`幂等撤销包装及流程，公开closed布尔。
- `isRefreshManaged() -> boolean`：只有会话活着、未暂停且本插件自动开关true时为true。
- `requestRefresh() -> boolean`：手动请求；在调用前源UI需返回实际阅读画面。
- `getMenuItems() -> table`：KOReader菜单条目，灰度开关及现有刷新子菜单；保存经会话偏好完成。
- `showMenu(return_to_reading)`：会话拥有的模态设置窗口，使用公共菜单；手动刷新先关闭设置并执行return_to_reading再排请求。关闭会话会清理其窗口。

`ImagePipeline.attach(widget, is_enabled, on_painted, on_error) -> controller`：on_painted只在原绘制或成功FS绘制正常返回后调用；错误回退成功也允许页面通知。controller.detach幂等且只还原自己仍持有的包装。所有绘制返回值保持。

`Refresh.new(reader, prefs, on_error, is_ready)`增加可选就绪判断；没有第四参数的原生文档调用行为保持。

### Task1：私有ImageWidget绘制接入

**Files:** 新graydither/imagepipeline.lua；新tests/imagepipeline_spec.lua、imagewidget_contract_spec.lua；fixture加入固定ImageWidget及来源hash；必要测试宿主桩在tests帮助文件。

**Produces:** ImagePipeline.attach契约。

- [ ] 写失败用例：关闭保留原图及返回值；FS黄金值输出与缓存独立；未绘制背景／透明／夜间／旋转；host软件抖动只路由普通合成，Screen值不变；异常释放并回退；后装包装保留。
- [ ] 复跑确认失败来自缺模块／缺行为。
- [ ] 实现私有ROI及局部目标绘制适配，调用真实ImageWidget语义，复用Algorithm.apply；禁止缓存原图变更与全局类覆盖。
- [ ] 完整灰度套件及真实ImageWidget合同通过，提交本任务。

### Task2：外部阅读会话与公共菜单

**Files:** 新graydither/imagesession.lua；修改main.lua、refresh.lua、必要refreshmenu.lua；tests/imagesession_spec.lua及plugin_spec.lua／真实UI合同。

**Consumes:** Task1 ImagePipeline.attach；既有Settings/RefreshSettings/Refresh。
**Produces:** 上述createImageSession和session契约。

- [ ] 写失败行为：FileManager创建不访问document；源开关false不继承全局true；独立偏好、首次／重复token不计、逻辑屏变化计数；settings取消、嵌入设置拒绝、暂停／关闭／插件停止撤销；手动返回正文后full；保留原生文档套件。
- [ ] 确认RED后实现会话、必要is_ready guard和菜单；服务从PluginLoader实例获取，停用关闭会话。
- [ ] 复跑全套及真实UI调度／黑白取消合同，提交。

### Task3：MangaWeb接入（独立工作树）

**Files:** mangaweb/ui/webdav_reader_shell.lua、ui/koreader.lua、现有reader设置默认／持久化文件；新spec/graydither_integration_spec.lua；只加入必要独立模块，不复制核心。

**Consumes:** Task2外部会话契约。

- [ ] 先建立当前0.8.83源码与相关既有reader tests基准，所有原工作文件保持。
- [ ] RED：global true下两个新开关仍false；保存与重启；服务缺失继续绘制；局部正文与稳定token接入；embedded_controls/loading/error/released暂停；更新／返回／关闭及休眠的取消；源授权路径继续使用既有入口。
- [ ] 从官方PluginLoader能力探测，传Adapter.reader_widget，store适配源reader偏好；正文ImageWidget包装、菜单入口及事件；对实际实现存在的分片／平移状态取稳定token，不新增这些显示功能。
- [ ] 源阅读行为与新行为套件通过，记录RED/GREEN和变动文件，提交。

### Task4：WebDAV漫画接入（独立工作树）

**Files:** webdavmanga/ui_reader.lua、ui_reader_shell.lua、settings.lua、必要ui_settings.lua；新spec/graydither_integration_spec.lua及定向现有回归。

**Consumes:** Task2外部会话契约。

- [ ] 先完整既有WebDAV所属基准（脚本--all）；失败如为宿主缺失明确隔离，不隐瞒。
- [ ] RED：默认关闭／单独持久化、服务无／禁用／异常回退；普通／象限／长条／分格局部正文attach；稳定屏token覆盖index/segment/pan/point/panel；设置、加载、重绘不计；关闭／休眠取消；每页全刷与动画仅在服务实际接管时临时停用。
- [ ] 最终shell统一接入，owner为shell.widget、ready依赖page模型；prefs独立保存，旧full_refresh_each_page值不改。
- [ ] 全套及相关reader退出／动画／长条／分格回归通过，提交。

### Task5：整合与独立审查／包验收

**Files:** 三仓库README／版本、包合同及升级说明；gray docs/external-readers-verification.md与执行记录。

- [ ] 用真实两个源shell与Gray会话＋固定BlitBuffer/ImageWidget/UIManager运行跨仓库合同；default-off、开关隔离、生命周期与原刷新恢复验证。
- [ ] 新上下文只读审查完整代码、缓冲归属、事件边界、设置与测试。重要发现写失败复现再修复，全套通过。
- [ ] 构建三个设备测试安装包，检查只有运行文件、名称版本、CRC／hash、源包字节及解包测试；不捆绑开发fixture。
- [ ] 整理给用户的安装顺序及验收方法；新发布影响在具体可审查产物完成后处理，不触碰真机。

## 执行与记录

用户“确认计划 开始”已授权实施范围与隔离方案，无需再询问是否继续任务。根代理实现公共核心，两名代理在不同源工作树实现独立接入；另用新上下文做最终审查。Task1→2依赖串行，Task3/4可依明确接口并行准备、实现；整合验收在公共核心就绪后进行。

每任务保留失败→通过证据、完整测试输出及提交，进展在docs/external-readers-progress.md记录。未知现有源问题不擅自修复；发现契约需要调整时先更新本计划接口并通知两个执行者。

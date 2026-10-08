# SDD ledger — plan: docs/superpowers/plans/2026-10-08-external-readers-plan.md

2026-10-08：用户确认计划开始，采用已确认A和每源两开关默认false。工作树gray/mangaweb/webdav隔离，原工作区不变。桌面原生worktree工具返回Not a git repository（聊天cwd不是repo），因此用git worktree fallback；路径全部位于原gray仓库ignored的.test-output/compat-work。

Pre-flight：Task1.attach→Task2.attachImage；Task2会话→Task3/4同名方法，store键约定一致。Task3/4互不共享产品文件。Task5依赖所有运行实现后做合同检查。

Ruling：用户已明确“确认计划 开始”，保留已授权的执行方式，补齐实施细节后连续推进，不重复请求已批准的设计/执行授权。发布三个新版本仍在具体包完成后单独核对授权与影响。

Task1: 完成私有正文ROI接入。6项单元测试先因缺模块失败；真实ImageWidget 14项合同曾复现正半像素少画一列与night处理失败，定位后修复，合同通过。原缓存与源alpha不变，仅实例包装，不改Screen标记；测试CBB关闭、MuPDF缩放入口受控替代，尚无真机证据。
Task2: 实现并通过初步测试。9项会话用例先因缺模块失败，FileManager入口用例先因缺服务方法失败；完整98项通过、10Lua编译通过。补充真实UI调度及菜单清理合同、独立审查仍进行。
Task3: 源代理实施，原38项纯合成基准通过，相关阅读回归及新默认false/存储/生命周期用例通过；准备实际Session联测。
Task4: 源代理实施，公开0.4.15完整基准192套件/107Lua通过。初次缺KOReader宿主，另一次CRC耗时3.101s超3s；原阈值定向及全套复跑通过，未放宽。新接入63项检查及完整回归进行。
Task5: 新上下文独立审查已启动。三仓库接口联测、版本及设备测试ZIP尚未完成，未发布新的接入版本。

契约补充：逐页下载的短暂loading如果每次清零计数，会永远无法触发自动全刷。因此pause(true)仅取消等待/阶段并暂停计数，保留最后成功屏和count；设置/休眠用默认pause()重建基准。根已通知两个源实现者并新增loading累计回归。source可通过session.closed判断Gray服务停用，恢复原阅读策略。

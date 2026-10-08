# 漫画灰度抖动最小插件设计

日期：2026-10-07。承接已交付的调研报告、B方案及用户“开始”的执行指令。本轮实现独立插件，不修改现有WebDAV/legado项目，不安装设备，不发布远端。

## 范围

插件名graydither.koplugin，版本0.1.0设备测试版。默认关闭。首先支持KOReader通过MuPDF绘制的CBZ/CBR固定页面；提供全局开关、单书开启/关闭/跟随、状态说明。颜色渲染页面采用RGB32临时缓冲，灰度页面采用BB8。输出是16个目标亮度，不声称原生256灰阶。不实现新gamma/主题/波形/自动内容识别，沿用宿主设置。

非CBZ/CBR、重排/页面优化/自动纠偏/非默认白色阈值、未知像素类型或缺少绘制能力时走原绘制路径，并显示可理解的状态原因。第一版对可运行KOReader宿主的平台提供相同插件目录；真实Kindle、Android、鸿蒙兼容性待设备测试。

## 接入与数据流

只在ReaderReady时包装当前文档实例drawPage；在CloseDocument时关闭并移除自己仍拥有的包装。未启用时直接调用原函数。即使全局关闭，单书强制开启仍可即时生效。不得更改UIManager、Screen、宿主类或进程级JIT设置。

启用且场景支持时：
1. 校验页面矩形与支持模式，最大宽高8192、最大像素8 Mi，超限不分配。源区域及tile excerpt必须为整数；目的坐标可以是非负小数，但原请求区域必须完整落在目标内，最终目的偏移按宿主checkBounds向下取整。负小数、有目标裁剪风险的小数或scaled_rect直通原绘制。
2. 创建与Document.renderPage输出相匹配的独立缓冲：render_color真时color_bb_type必须为BBRGB32，否则使用BB8。
3. 临时关闭当前document.sw_dithering，查询真实缓存tile核对类型与绘制交集；缓存只借用，不修改或释放。调用捕获的原drawPage写入临时缓冲，保持rect/pageno/zoom/rotation/gamma/saturation参数。
4. 不改变DocCache；不包装renderPage。
5. 仅对私有临时缓冲实际绘制区域的viewport处理，且只复制该交集到真实目标；不把未绘制背景经过灰度缓冲来回转换。禁止对缓存tile的共享viewport处理。
6. 无论成功失败都恢复sw_dithering和释放临时缓冲。失败调用原drawPage显示原图，不捕获/伪装原绘制自身错误。
7. 宿主硬件刷新仍由宿主负责，插件不修改波形或全局硬件开关。

若其他插件后来包装了drawPage，关闭本插件时不覆盖其函数；本插件残留包装被标记关闭并只转发。重复attach先detach旧控制器。

## 算法与职责

graydither/algorithm.lua：接受未旋转/未反色BB8或RGB32缓冲；pipeline保证传入的是私有缓冲的viewport，而非缓存共享内存。使用stride，不写RGB32 alpha或padding。整数亮度权重299/587/114并四舍五入，避免中性灰浮点下取整。标准从左到右FS：当前误差值限0..255，q=17*floor(v/17+0.5)，浮点误差按7/16、3/16、5/16、1/16扩散，复用两行数组。不新增原生库。

graydither/pipeline.lua：能力判断、文档实例包装、临时缓冲与错误回退；调用Algorithm.apply。只依赖KOReader现有BlitBuffer。

graydither/settings.lua：复用宿主G_reader_settings（LuaSettings）及文档DocSettings，两个作用域使用命名键graydither_enabled；不新建设置文件、不自行序列化文件名、不持久保存路径map。无效旧值视为跟随/关闭。

main.lua：菜单与ReaderReady/CloseDocument生命周期，设置改变后请求重新绘制；状态显示当前范围、启用状态与失败原因。_meta.lua只含用户可见描述和版本。

## 验证

使用已有Python/Lupa LuaJIT运行固定上游真实BlitBuffer源码，原生C blitter在Windows不可用，测试中关闭；FFI内存由真实allocator管理。页面原函数与真实设备UI需替身或源码级合同测试，不能声称真机通过。

黄金值：2x2输入8,9/128,246输出0,17/136,238；64x64灰51均值51；灰52、128、200的误差绝对值<=0.15；0/255及17*k不变。算法支持stride、alpha保护、非法格式/尺寸拒绝。页面连续20次从原图绘制输出相同且缓存源不变；测试旋转/反色目标、参数传递、异常释放与SW恢复、全局关单书开、包装共存/清理、非法设置值。

另执行固定版本真实Document.drawPage源码合同检查，覆盖页面矩形裁剪与夜间绘制路径；这仍不执行MuPDF原生库和真实屏幕。

## 交付与验收

可安装ZIP只含graydither.koplugin目录；源代码、测试、设计与规划保留独立项目。另给灰度验收CBZ。README明确安装路径、开关、已验证范围和绕过条件。公开发布/设备安装不在本轮操作内。

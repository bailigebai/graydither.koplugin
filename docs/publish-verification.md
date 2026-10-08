# 0.2.0独立发布验证

日期：2026-10-08。发布目标为bailigebai/graydither.koplugin；用户已明确授权公开发布。功能本地验收见refresh-verification.md，发布方案见publish-plan.md。

当前结果：[独立公开仓库](https://github.com/bailigebai/graydither.koplugin)及[v0.2.0发布页](https://github.com/bailigebai/graydither.koplugin/releases/tag/v0.2.0)已创建。GitHub API确认private=false、default_branch=main，latest Release为v0.2.0，draft=false、prerelease=false；标题及说明明确标记设备测试版。

## 发布候选内容

- 保留graydither.koplugin子目录，添加_meta.lua的静态name="graydither"，version="0.2.0"。
- 补齐README中的仓库、下载与琪琪市场操作说明，开发依赖记录为Lupa 2.8。测试、fixture和规划仅在源码仓库中保留。
- 去除公共复跑命令中的本机路径；原桌面补丁没有进入源码仓库或安装包。
- 灰度与刷新实现未因发布修改。
- .gitattributes固定公共文本换行为LF；第三方fixture保持原始字节，避免不同系统检出后hash变化。Git索引导出源码也执行完整68项检查通过。

## 本地证据

完整源代码与最终ZIP解压后的代码各执行68项测试，全部通过；8个产品Lua文件编译通过。打包脚本逐文件与源代码字节比对、验证CRC、单一根目录及3页800×1200验收漫画。

| 附件 | 字节 | SHA-256 |
|---|---:|---|
| graydither-0.2.0.zip | 30404 | 65a72526e5bb0f0b255f28d798db5b714bfc048f26078face45fac6d77d5dfce |
| graydither-test.cbz | 57717 | 4408a8a0b0052675919a2f8bac2fb19e4f0b83e3f8aa2c21b175bc2dad05977e |
| sample-preview.png | 5163 | 17fe1fb0c69ad170f8960275c58243cc38204a3b7a5de576cbda2dd55d56cdfc |
| manifest.json | 479 | 0757d5b5dfaf97d0a39cbf3a63c35bb6cbb4b93f1e9c9c9ef937f6bf8fb0ae56 |

四项附件从GitHub重新下载，均与本地文件字节一致；服务器返回的附件SHA-256也一致。远端ZIP的11项内容与产品源码逐文件一致、CRC通过；解压后的远端安装代码再次执行完整68项测试通过，8个Lua文件可编译。

新上下文只读发布审查放行：三处完整套件复跑通过，Git候选文件未发现凭据或本机路径，15条来源记录对应的Git文件hash匹配。没有关键或重要阻断；保留原灰度模块末尾空行以维持0.1.0字节一致。

## 琪琪市场契约

核对qiqiappstore.koplugin固定提交53070e4e5fa131b98b892d0160e6debd44310162（版本0.1.3）：它读取/users/bailigebai/repos的全部分页，筛选公开且owner一致、名称精确以.koplugin结尾的仓库，不要求topic或星标，也无需修改收录白名单。完整tree中必须只有一个同层包含_meta.lua与main.lua的插件候选；本仓库子目录符合该结构。

用户在项目详情中自行选择Release的ZIP附件；验收CBZ和预览PNG均不是安装包。市场保留本地缓存，设备上需要主动点“刷新缓存”。

发布前真实固定市场模块探针17项通过，覆盖账号筛选、完整分页、归档目录与静态名称/版本、唯一候选、截断tree拒绝、每次完整刷新和简介更新。市场列表简介来自GitHub仓库description，README另有缓存。探针中HTTP与宿主依赖适配，待发布tree为本地候选；此结果只证明规则符合，远端发布完成后另做实际API核对。

发布后探针23项通过，live_found=true、tree_source="real remote default branch"。实际公开API分页读到graydither.koplugin；默认分支递归tree对应e17723f6e8ca942bc11ed941abf9052b8259ba6b，真实远端_meta.lua和main.lua通过Git blob内容hash核对。真实市场policy识别单一插件候选，静态名称graydither、版本0.2.0，scope两次完整刷新把项目及中文简介写入测试缓存。审计只把账号列表缩小为当前项目以减少无关请求，未替换目标tree或元数据内容；KOReader宿主仍为替身，没有实际设备UI。

因此已验证公开仓库能够被当前琪琪市场的真实发现规则读取；设备已有缓存不会远程自动更新，须在商店主动刷新。市场程序和缓存格式均未修改。

## 设备验收与限制

联网打开qiqi 应用商店，刷新缓存并搜索graydither，选择v0.2.0的graydither-0.2.0.zip安装后完全退出并重启KOReader。阅读菜单应出现“漫画灰度抖动”和“墨水屏刷新”。

尚未执行真机操作：Kindle／Android／鸿蒙上的网络下载、安装、重启、实际显示与性能仍由设备验收确认；鸿蒙NEXT原生环境没有HAP。测试关闭原生C blitter，Screen／时钟及文档解码使用替身，不代表物理波形、残影或能耗验证通过。

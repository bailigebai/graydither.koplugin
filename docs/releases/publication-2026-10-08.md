# 2026-10-08 三插件公开发布核验

用户已授权“github都发布更新”。三个公开仓库默认main保留原历史直接更新，随后建立以下普通Release并指定为latest；均非draft、非prerelease，旧版保留。

| 项目 | 已发布版本 | Release对应提交 |
| --- | --- | --- |
| [GrayDither](https://github.com/bailigebai/graydither.koplugin/releases/tag/v0.3.0) | 0.3.0 | 44b664a23dfd0e1b053e70f02773555825b02413 |
| [MangaWeb](https://github.com/bailigebai/mangaweb.koplugin/releases/tag/v0.8.84) | 0.8.84 | 916e61139bb0d141feea7409be2433f29eba6de3 |
| [WebDAV漫画](https://github.com/bailigebai/webdavmanga.koplugin/releases/tag/v0.4.16) | 0.4.16 | 38c73480390f03198b43a1c57c282155f4047742 |

发布前改动只整理设备测试版下载说明，不修改运行代码、原生库或功能默认值。两个内置阅读器的灰度与自动全刷继续独立保存、首次默认关闭；软件16级抖动不等同于硬件256级灰度。

## 最终公开安装包

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| graydither-0.3.0.zip | 36998 | 6af6065c81c948f2f8bca6d55508d70f026bc5b97cc1a97cf13890b936340f0d |
| mangaweb-0.8.84.zip | 195649 | 927970796954119c00ef41270750fb97f2b23b81f397237e90c2a7dd94772cc6 |
| webdavmanga-0.4.16.zip | 873507 | ce7d437627905f0f22cb49b7f60593631fc527aa448dfdfd0fa92101599fe307 |

从GitHub回读三ZIP、三SHA校验文件及GrayDither测试CBZ/预览，共8个附件校验通过。三个ZIP的208个安装文件逐字节对应发布前已测试的清单；唯一插件根、版本、CRC、SHA和校验侧车一致。GitHub记录的asset digest与实际下载一致。发布前首次本地验收包的旧SHA保留为历史证据，不能用于核对当前Release。

最终GrayDither解包106项及10Lua通过；最终MangaWeb解包40组及67产品Lua通过，根另复跑随仓库保存的10组通过；WebDAV运行代码与完整193组/108Lua验收版一致，最终包合同32项及108Lua通过，根以最终两个解包产品复跑正文联测687项通过。

## 琪琪市场

按qiqiappstore.koplugin固定公开源码53070e4e5fa131b98b892d0160e6debd44310162的真实发现与下载规则匿名验证，2026-10-08T05:55:16Z首轮45/45项通过，退出码0。

每个项目均通过公开账号分页发现、唯一插件目录、main中的_meta.lua版本、release列表与latest一致、普通已发布版本、附件上传状态和准确下载地址；匿名下载三ZIP的SHA与本表一致，ZIP内版本也一致。

无需改市场代码或增加收录名单。在琪琪市场联网“刷新缓存”，选择对应版本的.zip；已安装旧版可进入更新管理“检查所有更新”。市场会把.sha256、测试CBZ、预览PNG也列出，安装需明确选择插件.zip。刷新列表不清README缓存，旧说明可在市场设置清理README缓存再打开。

本验证是公开接口和源码契约验收，没有运行真实市场设备UI，也没有安装设备或访问私人WebDAV/真实漫画。Kindle、Android和鸿蒙实机触控、画质、波形、残影与性能仍待用户验收。安装方法见[三插件说明](../external-readers-install.md)。

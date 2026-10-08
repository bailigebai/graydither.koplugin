# 来源与许可

本项目自有插件代码使用AGPL-3.0-only；完整文本为LICENSE。

## KOReader与测试fixture

运行时使用设备现有KOReader组件，不捆绑额外原生库。

- [KOReader](https://github.com/koreader/koreader)，固定提交646b2e39e24a899016d38ef6dc47e3f7c429c8ba，仓库COPYING为AGPLv3。
- [koreader-base](https://github.com/koreader/koreader-base)，固定子模块9e9befc73f494556e2ff0732940e84fa9d0b6dac，仓库COPYING为AGPLv3；具体文件声明仍按文件本身。
- tests/fixtures包含未经修改的BlitBuffer、Document、KoptInterface及UIManager、Widget、Event、Geom、ReaderRolling等源码和许可文本，仅用于本地合同检查，不进入安装ZIP。
- 来源URL及SHA-256见tests/fixtures/provenance.json。源码保留原有头部；它们不归本项目作者所有。
- Windows测试仅对OS声明、工具函数和未执行的UI／解码依赖提供测试桩；不改变fixture源码，原生C blitter关闭。

## 功能与算法调研参考

- [4285f4/dither256.koplugin](https://github.com/4285f4/dither256.koplugin)：README声明AGPL-3.0。参考其产品功能、FS思路和审计问题；本项目重新实现算法、设置与生命周期。
- [Euphoriyy/appearance.koplugin](https://github.com/Euphoriyy/appearance.koplugin)：GPL-3.0。参考页面绘制接入思路，未复制其外观实现。
- Floyd–Steinberg使用标准误差扩散权重7/16、3/16、5/16、1/16；采用浮点误差保留精度和整数RGB亮度四舍五入。
- 其他调研项目未作为运行依赖或复制代码引入。未授权／限制商用的修改版应用不作为代码基础。

GitHub源码仓库保留上述来源、完整许可文本与fixture来源清单；设备安装包只包含独立插件及README、LICENSE、THIRD_PARTY说明。

## 用户提供的全刷补丁

2026-10-08读取桌面“全刷阅读插件”目录的安装说明.txt与2-eink-full-refresh.lua。文件标注原作者“纯汉字名真难起”，B站主页space.bilibili.com/260834225；所提供目录未见LICENSE或明确授权声明。

本项目参考其手动刷新、自动间隔和黑白保持的功能，独立编写普通.koplugin配置、控制器及菜单。不复制原补丁、全局hook实现或作者二维码，不把无许可原文件纳入AGPL安装包。原作者归属按输入材料保留在本说明中；来源事实不等于再许可授权。

刷新合同参考[固定UIManager源码](https://github.com/koreader/koreader/blob/646b2e39e24a899016d38ef6dc47e3f7c429c8ba/frontend/ui/uimanager.lua)、[Android适配](https://github.com/koreader/koreader/blob/646b2e39e24a899016d38ef6dc47e3f7c429c8ba/frontend/device/android/device.lua)及[固定WidgetContainer事件传播](https://github.com/koreader/koreader/blob/646b2e39e24a899016d38ef6dc47e3f7c429c8ba/frontend/ui/widget/container/widgetcontainer.lua)。本地测试对Screen和时钟提供替身，不能验证物理波形或残影。

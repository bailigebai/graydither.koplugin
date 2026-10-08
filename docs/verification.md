# 0.1.0 本地验证记录

日期：2026-10-07。结果：最小插件、设备安装ZIP、三页验收CBZ完成。当前为设备测试版，尚未在Kindle、Android或鸿蒙设备安装运行。

本记录为0.1.0的历史验证。2026-10-08整合全刷后的当前版本证据见refresh-verification.md；验收CBZ会随打包重新归档，当前hash以dist/manifest.json为准，0.1.0 ZIP保留原文件。

## 本次交付

独立项目graydither.koplugin；当前文档实例接入，CBZ／CBR普通MuPDF分页绘制。默认关闭，提供全局默认及单书开启／关闭／跟随。采用私有BB8／RGB32缓冲进行16阶Floyd–Steinberg抖动，保留源缓存与宿主参数，异常恢复软件抖动设置并回退原图。关闭文档清理包装，保留后来的第三方包装。

未知格式、优化模式、像素类型、超限区域及不安全小数几何直通原绘制。宿主刷新与硬件波形仍由KOReader负责。

## 自动检查证据

源码完整套件及安装ZIP解压后套件均返回exit code 0：

| 套件 | 通过数量 | 主要验证 |
|---|---:|---|
| algorithm_spec.lua | 10 | 黄金矩阵、固定灰阶与均值、RGB32亮度、alpha／stride、20次源复制稳定 |
| pipeline_spec.lua | 16 | 缓存不变、参数与返回值、异常释放／设置恢复、包装共存、裁剪及居中 |
| settings_spec.lua | 6 | 全局／单书优先级、false与nil、无效值、宿主存储 |
| plugin_spec.lua | 6 | 实际菜单回调、全局关而单书开进入处理、生命周期及状态 |
| kopt_contract_spec.lua | 1 | 8种固定Kopt夜间绘制路径组合 |
| 合计 | 39 | 5个产品Lua文件编译通过 |

pipeline套件内部包含32种格式／旋转／反色／夜间组合、192种源／目标格式与裁剪组合、192种小数居中组合。另验证683×1024页面在758×1024目标上x=37.5的适页位置，以及四种危险小数位置保持原绘制。

环境：现有Python 3.11、Lupa LuaJIT21，LuaJIT 2.1.1774896198；未安装新依赖。测试执行真实FFI分配、复制与释放。UI和MuPDF解码依赖使用测试替身，原生C blitter关闭。

固定上游：KOReader `646b2e39e24a899016d38ef6dc47e3f7c429c8ba`，base `9e9befc73f494556e2ff0732940e84fa9d0b6dac`。真实BlitBuffer、Document、KoptInterface源码及许可的hash在tests/fixtures/provenance.json中，测试前逐项验证。fixture不进入设备ZIP。

本机复跑：

```powershell
python scripts/run_tests.py
python scripts/run_tests.py --plugin-root .test-output/unpacked/graydither.koplugin
```

## 独立审查与修复

新上下文只读审查发现部分源裁剪时未绘制背景被抖动，以及BB8临时缓冲往返会把RGB32背景灰度化。先加入失败复现，再限制处理与回写为真实tile绘制交集，移除背景往返转换。192组合回归全部通过。

上游ReaderView核对发现正常居中也会产生.5目的坐标。先新增“成功处理次数为1”的失败复现，再仅允许非负且整个原请求区域落在目标内的小数目的位置，最终copy按照宿主floor规则对齐。负小数及目标边界裁剪仍传递原参数直通。

最终独立审查复跑39项通过，另报告237,500组一维checkBounds比较未发现退化；该额外审查探针不计入可重复运行的39项套件。审查没有代替原生CBB或真机验证。

## 产物核对

安装ZIP共8个文件，根目录为graydither.koplugin/；包括5个Lua文件及README、LICENSE、THIRD_PARTY。每个文件与源目录逐字节比对一致，ZIP CRC通过，不含测试／构建脚本或额外原生库。验收CBZ含3张800×1200的8位灰度PNG，CRC及尺寸检查通过，第一页预览已目视检查。

| 产物 | 字节数 | SHA-256 |
|---|---:|---|
| graydither-0.1.0.zip | 22729 | 54fca6e90c96cd3482d3a426bc1858dbfbbfc98b991e246fa7336c774b1ad0b3 |
| graydither-test.cbz | 57717 | 3c0d330d753b63a2c788404183ce5e13e1a9f67a40d04950c84eb1a400339233 |

dist/manifest.json记录当前全部产物hash；重新打包会更新清单。

## 用户验收与待验证

解压ZIP，把graydither.koplugin放入实际KOReader数据目录的plugins内，重启并打开配套CBZ。阅读菜单查找“漫画灰度抖动”，选择“本书：开启”；翻页后状态中的成功处理次数应增加。对照开启／关闭的渐变、纯灰与细线，反复显示同页20次，检查亮度不持续下降。再验收横竖屏、夜间模式、宿主刷新选项及全局／单书开关优先级。详细安装与关闭方法见README。

待确认：具体设备型号、系统／固件、KOReader版本；真机ABI与CBB、MuPDF解码、Android最终窗口反色、Kindle画质、翻页速度、峰值内存、耗电、残影，以及其他绘制插件共存。鸿蒙APK兼容环境与NEXT／5+原生环境需分别确认；本项目不提供HAP。CBZ／CBR以外格式不在首期范围。

本轮只创建独立本地项目和设备测试包，保留feature/graydither-mvp分支；未修改其他现有项目、安装设备或推送发布。

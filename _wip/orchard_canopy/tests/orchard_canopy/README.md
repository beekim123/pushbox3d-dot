# 桃冠有界 QA 与历史证据

只包含约定脚本、文本报告；截图位于 `screenshots/orchard_canopy/`。没有旧工程副本、Blender中间版本、`.godot`、XDG用户数据、锁或续玩sidecar。

## 生产复拍（需要实际图形桌面）

```sh
GODOT=/absolute/path/to/godot-4.7.2 QUALITIES=high \
 bash tests/orchard_canopy/run_native_capture.sh "$PWD" /tmp/orchard-qa-output
```

不传基线参数时使用游戏真实自动取景；脚本只写输出目录，不改生产源。默认高/低两质量，指定`QUALITIES=high`只拍高质量。脚本强制QA隔离保存；输出目录内会产生`.qa_env`，**不得把它收进发行包**。音频使用Dummy，不能据此声称试听。Linux shell脚本不宣称macOS测试通过。

可选第三参数 `tests/orchard_canopy/native_before_capture_manifest.json` 用于严格匹配历史基线相机。匹配图和自动取景图不是同一种证据。

## 源与预览

`render_comparison_final.py`接收Blend路径、输出PNG路径、`lineup`或`garden`参数：

```sh
blender --background --python tests/orchard_canopy/render_comparison_final.py -- \
 blender/heaven_orchard.blend /tmp/orchard-lineup.png lineup
```

三树选择性重建命令与范围见 `docs/orchard_canopy.md`。

## 证据出处

`integration_manifest.json`、独立审查及几何/语义报告保留原始内容与hash，原路径中的`canopy_review/`指隔离制作阶段，不表示发行包内有重复工程。`native_before_*`与`native_final_*`为历史候选比较manifest；生产合入后的证据单独标识。没有把这些历史报告改写成新执行时间。

截图映射：原`native_before/`→`screenshots/orchard_canopy/matched_before/`，原`native_final/`→`matched_final/`；其中`native_`前缀图保留自动取景。原生生产图另放`production/`。四张Blender前后预览直接放截图根。未导出被拒绝的`native_after/`。

所有报告的“通过”限于各自列明范围；几何/材质语义相同不等于GLB字节确定性。Git二进制限制不因本目录纯文本保全而解除。

便携语义比较：`python tests/orchard_canopy/semantic_glb_compare.py BEFORE.glb AFTER.glb --output /tmp/semantic.json`。只比较三角形、POSITION/NORMAL与材质，不检查节点层级/变换；这些在本次独立报告中另行核对，不能把该工具当完整场景等价证明。历史repro2_raw二进制未打包，故历史排序实验只保留报告，不宣称在发行包内可复跑该对比。

`production_capture_manifest.json`、`production_verification.json`、`production_capture.log`来自最终生产工程：4匹配＋4自动取景图。所有对应PNG与最终候选逐字一致，仍保持main b529ffb及world_view原SHA。

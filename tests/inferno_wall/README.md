# 地牢墙 C0.80：生产证据与便携 QA

- `ISOLATED_BUNDLE_README.md`与54文件manifest保留隔离阶段原文/hash；其中“尚未合入生产”是冻结时历史状态，不是当前状态。生产说明见`docs/inferno_wall.md`及`production_native/`。
- `qa/`与`reports/`、`evidence/`内JSON是文本证据；原16张PNG在`screenshots/inferno_wall/`，保留native_before/native_after/blender结构。这里的native_after明确是最终C0.80，不是中间被拒绝B0.88。生产三图另在production_native。
- 没有复制基线工程、重建探针、.godot/.qa_env、用户存档或.blend1。历史绝对路径只表明出处，不作为便携脚本运行依赖。
- `qa/audit_final_c80.py`是在冻结原版上只加`--images-dir`与`--output`的集成适配（SHA ce99afb754d15a9a8825f93f0898def212b479e149b3fb15e0296eaa8ca35a40），原54文件manifest未篡改。JSON仍在本目录，图片可分包；已对生产真实运行，结果见`tests/results/inferno_wall_portable_validation.*`。

工程根执行，需截图包与Python3/Pillow：

```sh
python tests/inferno_wall/qa/audit_final_c80.py --project . \
 --images-dir screenshots/inferno_wall --output /tmp/inferno-report.json \
 --allow-cosmetic-tooth-occlusion
```

真实图形桌面复拍当前生产第10/23/45关：

```sh
CAPTURE_SCRIPT="$PWD/tests/inferno_wall/qa/native_capture_production.gd" \
 GODOT=/absolute/path/to/godot-4.7.2 QUALITIES=high \
 bash tests/inferno_wall/qa/run_native_capture.sh "$PWD" /tmp/inferno-native
```

可选第三参数基线manifest用于核对相机而非静默挪镜头。输出含隔离`.qa_env`，不要收进发行包。音频Dummy，不能当试听；引擎图形截图不冒充人工解题或硬件键盘测试。

有限表面采样仍有4119装饰定位齿命中，接受核心符号可读不等于全表面零遮挡。详见主文档、独立报告和原始失败列表。GLB语义比较不保证字节复现，脚本覆盖范围以自身说明为准。

## 当前版本权威

当前仅以 `FINAL_C80_INTEGRATION_MANIFEST.json`（fc31becb…）为核心文件合入清单；生产事实另看独立生产补记与production_native验证。误混入根目录的旧A交付manifest已原样移至 `historical/A063_delivery_manifest.json`，明确标为历史，不用于当前验证/构建。不存在未标识的旧validation_summary.json；原54文件中的 `reports/FINAL_C80_VALIDATION.json`仍为C0.80报告。

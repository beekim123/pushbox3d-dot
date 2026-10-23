# Daylight 渲染微调 · 2026-10-23

在隔离 lookdev 中对 baseline、daylight、softbox、filmic 做真实 Godot 同镜头比较后，经父任务批准采用保守的 **daylight**。花瓣/枝干、木篮与石径更清楚；不是重建模型，也不声称美术已获玩家认可。

## 唯一运行源码改动

`scripts/world_view.gd`：ambient 0.18→0.15，Linear exposure 0.80→0.90，主光 energy 0.36→0.60、pitch -54°→-48°，填充 0.050→0.055；背景按六个受控主题色混合 22%。灯数、阴影设置、相机、Blender 模型/材质、规则、UI 均不变。没有模糊、雾或新增后处理。

- 原 SHA256：`da7cacb34f8fc3d75bb0355bc07352664ed8781ee09ac46319c16e7837caebe7`
- 新 SHA256：`b73a8cad67115445cf9c9bdb0c6312dd5280a0fe43c1c2ddc0ec11b021893a6d`

## 集成验证

使用精确 Godot 4.7.2、GLCompatibility：

- 干净导入通过，退出 0：`tests/results/daylight_import.log`。
- 全 **204** 关相机构图：**0 HUD 裁切**，退出 0：`daylight_camera_fit.log`。
- 全 **1,632** 个提示布局状态：**0 合法格重叠**，退出 0：`daylight_hint_layout.log`。
- 生产真实捕获四世界第 45 关：`screenshots/daylight/`，不覆盖旧截图。
- 捕获程序只断言生产灯光参数，不覆盖参数；四幅图与已批准隔离候选 **逐像素完全一致**，镜头和几何计数相同，无缺失资源。证据：`tests/results/daylight_pixel_parity.json` 与 `daylight_production_capture.log`。

## 质量与性能边界

隔离实验覆盖四世界第 10、45 关及中庭/交汇，35 张同条件对比。daylight 所有有效地面样本均无通道夹断；主/次文字对比最低 15.06:1 / 8.09:1。softbox 因偏白、过于明亮而淘汰；本次 filmic 组合明显过曝，未采用。

完整重负载回归结束后做八组交错 baseline/daylight 帧时比较：变化 -6.9%～+13.0%，均低于预设 +15% 警戒线；draw calls/primitives 全部不变。共享云端 llvmpipe 有噪声，**不承诺加速、硬件 GPU 表现或 60 FPS**。集成截图时并行运行布局检查，集成捕获日志中的帧时不作性能基准。

宽阔平草地、外围摆件重复与部分岩石造型仍属于后续 Blender 构图/建模工作。本次未触碰这些资源，未全面逐张视觉验收 204 关。

## 复现命令

先设置独立可写的 XDG_DATA_HOME / XDG_CONFIG_HOME / XDG_CACHE_HOME；捕获在有显示服务的图形终端执行。测试脚本包含实验参数常量仅作比对断言，**不会写入/覆盖生产灯光**。

```sh
godot --headless --editor --import --path . --quit
godot --headless --audio-driver Dummy --path . --script res://tests/camera_fit_v2.gd
godot --headless --audio-driver Dummy --path . --script res://tests/hint_layout_checks.gd -- --qa
godot --path . --audio-driver Dummy --resolution 1440x900 --script res://tests/daylight_capture.gd -- --qa --quality=high --lookdev-worlds=heaven,inferno,rainforest,city --lookdev-level=44 --lookdev-variants=daylight --lookdev-output=res://screenshots/daylight
```

`godot` 必须指向 4.7.2；最后一条会重建 daylight 证据目录中的同名图，不触碰历史 `screenshots/v2/`。

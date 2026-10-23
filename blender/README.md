# 原创 Blender 资产与重建（V2）

所有运行时 3D 几何、材质与关键帧动作由本项目的 Blender 脚本制作，导出为独立 GLB。没有下载或导入外部图片、模型、材质包、角色或动画。Godot 运行不需要安装 Blender。

## 当前重建顺序

在工程根目录运行：

```sh
blender --background --python blender/generate_courier_hub.py
blender --background --python blender/generate_orchard.py
blender --background -t 4 --python blender/rebuild_worlds_v2.py -- inferno rainforest city
blender --background --python blender/generate_hub_garden.py
python blender/audit_glb.py
```

- `generate_courier_hub.py` 现在默认只生成原创建模和骨骼动画的邮差。`--legacy-hub` 是旧版归档重建选项，不应在 V2 交付中使用。
- `generate_orchard.py` 生成蟠桃园树木、花、果实、岩石、草地、月牙仙池、箱子、目标与完整庭园。设 `FOURFOLD_SKIP_RENDER=1` 可跳过 Cycles 预览渲染。
- `rebuild_worlds_v2.py` 负责其余三界的重新制作；不加 `--` 参数也默认生成三界。支持 `FOURFOLD_SKIP_RENDER=1`、`FOURFOLD_RES=65`、`FOURFOLD_SAMPLES=64`；默认 1500×1150、64 samples。
- `generate_hub_garden.py` 生成四叶形中庭、旧石铺地、木织机与园景。
- `model_helpers.py` 是基础几何工具；`generate_assets.py` 保留部分原始通用辅助接口，不是 V2 的总重建入口。不要直接运行它覆盖新版世界。

## 源文件

- `heaven_orchard.blend`：可编辑桃枝、花瓣、果实、岩石、池岸和园景组成。原始物件保留，运行时 GLB 按材质合并。
- `inferno_v2.blend`、`rainforest_v2.blend`、`city_v2.blend`：对应三界的 V2 源文件。
- `hub_garden_v2.blend`：四叶庭园和木织机。
- `courier.blend`：六骨骼刚性蒙皮角色，`idle / walk / push / celebrate` 四个 Blender 动作。

旧版宫殿源文件和自动 `.blend1` 备份移至工程外的版本备份，不作为 V2 美术交付重复堆放。

## 坐标与布局

- Godot 网格边长 2，Y 向上；Blender Z 向上、-Y 朝前，通过 glTF 转换成 Godot +Z 朝前。
- 单格铺地顶面 Y=0；世界景观安全中心为 ±7（名义 7×7 格），顶面约 Y=-0.03。运行时只按关卡宽高缩放景观 X/Z，不缩放高度。
- 大桃树、房屋、炉窟、树冠等地标放在可玩区外围，不代替墙或遮住路径。
- 主角、机制和生物动作均来自 Blender 动作片段。运行时可以移动实例以落实格子规则；没有程序临时生成最终模型。

## 性能与验证

- 蟠桃园花瓣使用共享浅杯五瓣网格生成，静态 GLB 在导出时按材质合并；大桃树 12 个材质网格、39,100 三角形，而非数百花瓣 MeshInstance。
- `audit_glb.py` 检查 GLB 文件头、动作名及无图片纹理/外部缓冲依赖；结果写入 `glb_audit.json`。
- Blender 安装包缺少可选 Draco 库，会在导出器注册时打印该提示；这里不使用 Draco，GLB 正常不压缩导出。
- 此 Blender 缺少 OpenImageDenoise，Cycles 明确关闭降噪。预览是 Blender 实际渲染，不是 AI 生成图，也不是参考图。
- `screenshots/blender_heaven_v2.png` 等为制作证据，不被当作运行时贴图。

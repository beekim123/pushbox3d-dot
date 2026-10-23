# 焰井地牢：障碍墙 C0.80 有界改良

## 设计与范围

旧墙的平行淡紫肋条容易看成加高地砖。新墙用六块不均匀圆角砌石、两层错缝、深梅紫侧面和克制的暖色石顶，让不可走格更像实体砌墙。模型、材质仍由原创Blender代码制作。

本阶段有意把原先自定的0.63米高度门槛放宽为0.80米，**不是声称仍符合原高度门槛，也不是更改用户硬要求**：只加厚下层0.17米，X/Z占地、材质、铜管、运行时变换、边界缩放、地形、镜头、光照与玩法不变。B0.88因新增遮挡核心金色目标环被拒绝；C0.78未消除装饰定位齿局部遮挡，体量也更弱。

最终接受C0.80的取舍：目标的象牙色定位齿出现额外局部遮挡，属于已记录的装饰性成本。**不是零遮挡结果。** 核心金环、传送泉涡和合法格中心在已检查视角可读，在所述有限几何采样中无墙命中。

| 资产 | 原三角形 | C0.80三角形 | 材质批次 |
|---|---:|---:|---:|
| inferno_wall | 940 | 552 | 2→2 |
| inferno_wall_b | 3,884 | 3,496 | 4→4 |

最终更新四个核心文件（`blender/rebuild_worlds_v2.py`、`blender/inferno_v2.blend`、两墙GLB）及`blender/v2_inferno_stats.json`。其它60 GLB含桃树、运行脚本、关卡与工程设置不变。每次构建的SHA固定本次验收字节，不承诺Blender导出字节确定性。

## 遮挡证据如何解读

- 精确导入网格审计覆盖51个地牢皮肤关卡、1070合法格中心（908邻墙）、86580金环表面点、910350泉涡表面点，墙命中均为0。
- 点来自面向镜头三角形的顶点、边中点与重心，并用自身网格射线排除符号自身遮住的候选点。这是有限、非面积归一的采样，**不是像素遮挡面积，也不是所有动画帧证明**。
- 装饰定位齿命中：原版711、A0.63为414、C0.80为4119。按关卡/类型/世界坐标逐点比较，C比原新增3408：顶面95、上斜面1991、侧/下部1322。分类用容差阈值，不能把未修正的浮点边界标签当最终分区。
- 全表面零遮挡测试仍失败，不能改写成通过；接受门槛明确区分核心符号与装饰齿。精确泉涡表面测试只在初始姿态，另用导入发光网格推导的保守全旋转最低高度盘补测73440点，0命中；仍不等于像素完整动画测试。

## 实际验收与范围

最终候选第10/23/45关高低质量六张1440×900原生图、Blender前后预览已独立检查。相机、光照、目标/箱子投影、渲染缩放与MSAA成对一致，动画固定初始姿态；没有偷偷挪目标或镜头避开遮挡。第10/23/45关draw-call分别234/234/244，成对不增加，不宣称软件渲染60fps。

生产合入后重新导入、30帧启动、204关相机/HUD审计、62模型/6Blend源审计均通过。新全204真实处理器8056检查、0失败、退出0，74个运行/关卡/模型指纹前后一致；QA关闭续玩sidecar，所以不替代存档功能专项。证据在`tests/results/inferno_wall_*`。

生产另拍第10/23/45关高质量三图，PNG逐字等于最终接受候选，89文件前后hash及行指标一致。报告在`tests/inferno_wall/production_native/`，PNG在`screenshots/inferno_wall/production_native/`。原生llvmpipe日志存在不支持切换VSync的驱动警告；没有把它写成零警告。当前仅Linux/X11实测，不声称macOS/Retina验证。

## 复建与复验

工程根运行，仅重新导出两堵墙：

```sh
FOURFOLD_EXPORT_ONLY=inferno_wall,inferno_wall_b FOURFOLD_RES=70 FOURFOLD_SAMPLES=32 \
 blender --background -t 4 --python blender/rebuild_worlds_v2.py -- inferno
```

不设导出过滤仍保留原完整地牢重建行为，独立无过滤smoke导出14资产。可编辑Blend和源码保留，运行游戏不要求Blender。

便携证据检查需Python/Pillow及单独截图包：

```sh
python tests/inferno_wall/qa/audit_final_c80.py --project . \
 --images-dir screenshots/inferno_wall --output /tmp/inferno-validation.json \
 --allow-cosmetic-tooth-occlusion
```

明确传最后参数才接受已批准的装饰齿取舍；工具不会把全表面失败改写为零遮挡。截图包未展开时应先取得截图，不伪称仅文本即可完成像素审计。复拍命令与目录映射见`tests/inferno_wall/README.md`。

Git二进制审批仍未解决；源码提交不含新墙GLB/Blend，远程checkout不可当成新美术完整发行包。本阶段完整资源需主任务另行打包、校验与交付；此前已发桃冠归档保持原样。

当前核心文件权威为 `tests/inferno_wall/FINAL_C80_INTEGRATION_MANIFEST.json`（fc31becb…）。较早A0.63的交付manifest仅在historical目录保留追溯，不用于当前合入或构建。

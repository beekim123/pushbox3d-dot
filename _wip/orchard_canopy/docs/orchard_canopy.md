# 蟠桃仙园：桃树花冠有界改良

本阶段只更新主桃树、偏侧双树与幼树，以及对应生成脚本和可编辑 Blender 源。不是新玩法版本，也不代表玩家已认可全部美术。

## 造型与范围

- 三种树使用不同、连通的枝干骨架；浅厚、不规则的五瓣花扇形成连续粉色花冠，保留枝间空隙和仙桃，而非粉色球冠或均匀散点。
- 原生右向视角曾出现大块深暗衬底。通过减少重叠花扇衬底、收薄局部几何、使用已有暖粉下侧材质修正；没有改全局灯光、关闭阴影或修改相机代码。
- 仅五个生产文件改变：`blender/generate_orchard.py`、`blender/heaven_orchard.blend`、`assets/models/heaven_{landmark,landmark_b,decor_a}.glb`。共享目标花、其它地形/模型、204关、规则、完成态与续玩代码保持不变。

| 模型 | 之前三角形 | 最终三角形 | 材质网格 |
|---|---:|---:|---:|
| 主树 landmark | 39,100 | 30,184 | 12 |
| 双树 landmark_b | 62,664 | 41,204 | 12 |
| 幼树 decor_a | 38,260 | 15,412 | 12 |

三树AABB均在原包络内。这里的12材质网格是每资产的结构指标，不把它当成整个场景的draw-call总数。

## 复建

运行游戏不需要Blender；仅重新制作美术时需要Blender 4.3.2或兼容版本。在工程根运行：

```sh
FOURFOLD_SKIP_RENDER=1 FOURFOLD_ORCHARD_EXPORT_ONLY=landmark,landmark_b,decor_a \
  blender --background -t 4 --python blender/generate_orchard.py
python blender/audit_glb.py
python tools/audit_assets.py
```

生成脚本重建可编辑全园`.blend`，但只重新导出三树GLB，避免无关资源重写。**不支持字节级可复现承诺**：Blender导出器排序实验未使重复导出SHA一致，已撤回该实验。冻结SHA标识本次交付构建；语义检查核对定向三角形/法向与材质（1e−6），独审另外核对节点变换和层级。未来重建需重新核验，不能只凭源码相同宣称相同二进制。

## 验证与交付边界

- 隔离候选最终字节经独立像素审查：第3/10/45关与中庭，高/低质量共8张原生图；另有2张Blender预览。早期出现暗块的中间版本不是最终验收图。
- 精确对照图使用QA基线相机；自动取景图另存，不能把两者混称。匹配视角的箱子/目标投影、光照、draw-call保持一致；没有宣称软件渲染达到60fps。
- 合入生产后重新导入与30帧启动退出0；全204关相机/HUD审计裁切0，62模型及6Blender源审计无错误。证据在`tests/results/orchard_canopy_*`。这些是美术有界回归，不替代之前的8056玩法检查或存档测试。
- 放大预览仍有浅粉垫状边缘这一非阻塞风格化余项。当前证据来自Linux/X11，不覆盖macOS/Retina。
- Git二进制上传限制仍存在，源码提交不等于远程仓库已有新GLB/Blend。完整发行ZIP才包含本次冻结模型；发布与附件由主任务单独核实，不在此页提前声称已上传。

生产合入后又实拍4张匹配视角＋4张自动取景高质量图，1440×900，第3/10/45关及中庭，与最终接受候选对应PNG逐字一致、输入hash及行指标吻合；证据 `tests/orchard_canopy/production_verification.json`，截图 `screenshots/orchard_canopy/production/`。

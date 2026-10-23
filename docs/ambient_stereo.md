# 四世界环境音：右声道权重定点修复

环境底噪合成右声道遗漏了与左声道一致的`/(k**.55)`分量衰减。本轮只补这一处公式，按原随机种子和四世界次序重新合成四条16秒环境音。没有引入录音/下载素材，也没有改曲谱、总线音量或玩法。

## 精确范围

六文件：`tools/generate_audio.py`、四个`assets/audio/*_ambient.ogg`、`audio_validation.json`中四条环境音记录。其余六首音乐、八个音效共14文件及完整记录不变；manifest顶层字段不变。main50ff、模型、关卡、音频路由/增益不动。无损WAV只在工作区复核，不收进项目。

| 世界 | 原右−左RMS dB | 修正后右−左RMS dB |
|---|---:|---:|
| 蟠桃仙园 | +13.4621 | +2.5101 |
| 焰井地牢 | +12.8510 | −0.0167 |
| 雨林 | +14.2236 | +1.6657 |
| 山城 | +11.8739 | −0.3483 |

保留有意声像事件造成的自然左右差异，不要求严格居中。这里只证明数值失衡修正，**没有主观试听或“听起来更好”的结论**。

## 已验证与局限

- 四条均32kHz立体声、512000帧/16秒；有限采样、无达到0.99绝对幅值或削波样本；每声道DC均值<1e−4；边界差/最大内部差≤1.1；无连续≥100ms的内部低于−60dBFS窗口；|右−左RMS|≤3dB。独立按修正源码重构/编码与交付解码样本一致，清单hash核对通过。
- 独立全新Godot4.7.2导入：18/18音频实际解码通过，10条循环越过首轮仍有非零样本，8个短音效到EOS误差≤0.12ms。Dummy驱动直接解码不等于扬声器/耳机试听、感知接缝或混音真峰值验证。
- 生产重新导入exit0；实际游戏四世界路由和正常`finish_exit`清理26检查/0失败、exit0，日志干净。生产数值复验和移植后便携验证分别保留。
- 负向诊断必须保留：最初用`--quit-after30 --headless-audio`强制结束，虽exit0却泄漏4个ObjectDB/2个资源，绕过游戏约0.3秒音频清理。它**不算干净启动通过**；后续以真实正常退出路径验收，不隐藏失败日志。
- 最近8056全关检查发生在音频替换之前。运行/模型输入未变，但不能把旧8056说成音频更新后重新跑过。当前是有界音频回归，不证明跨平台音频设备、主观作曲质量或完整混音峰值。

## 便携复验

依赖Python、NumPy、FFmpeg/ffprobe；不联网安装，不在工程内写WAV母带：

```sh
python tests/ambient_stereo/verify_ambient_candidate.py --project . --output /tmp/ambient-verification.json
```

脚本读取`historical/audit_results.json`作为不可变旧基线；只将新结果写到显式输出。原诊断和候选接受报告按原时间保留，不改写成当前仍有未修失衡。

正常游戏路由检查，使用隔离用户目录并从工程根调用：

```sh
XDG_DATA_HOME=/tmp/fourfold-audio-test XDG_CACHE_HOME=/tmp/fourfold-audio-cache \
 godot --headless --audio-driver Dummy --path . \
 --script res://tests/ambient_stereo/graceful_audio_smoke.gd -- \
 --qa --headless-audio --audit-output=/tmp/ambient-runtime.json
```

须使用Godot4.7.2。实际测试是Linux云端；不承诺XDG在其他平台同样隔离。Git审批仍未完成，源码和本地资源修复不代表远端已发布；新版完整ZIP由主任务另行验证交付。

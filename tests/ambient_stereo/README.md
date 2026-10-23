# 环境音定点修复证据

- historical：修复前数值诊断、基线/负向对照，以及一次强制退出绕过音频清理的泄漏日志；不是当前仍未修复的状态，也不能当干净通过。
- candidate：独立精确六文件允许清单、修正数值、全新引擎18音频解码/循环证据；原文“生产未改”仅指审查当时。
- production：实际合入范围、root数值验证/正常路由26检查、移植后再跑数值结果。

`verify_ambient_candidate.py --project PROJECT --output REPORT.json`读取固定historical/audit_results.json；`audit_audio.py`仅作为原DSP验证依赖，单独执行也要求显式--project与--output目录。只改路径/输出参数，不改阈值或数值逻辑。没有复制WAV母带、导入cache或用户目录。

`graceful_audio_smoke.gd`必须传--audit-output；使用正常finish_exit，不用强制quit-after冒充退出清理验收。直接解码和Dummy路由不代表试听或音频设备验收。详见docs/ambient_stereo.md。

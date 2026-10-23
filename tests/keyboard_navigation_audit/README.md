# 独立键盘审查证据

`independent_frozen/`保存最终50ff源码的293断言原报告和最终CUA/Sky桌面事件；其“production remains b529”是审查时真实状态，不被事后篡改。`production_native/`及补记记录后来本地生产合入，不能冒称远程Git已合入。

`history_5a9a4e/`仅是旧版历史，不用于最终50ff通过数或截图证明；对应PNG也在明确的历史目录。最终图分别在`screenshots/keyboard_navigation/independent_final_50ff/`与`production_50ff/`。

`original_driver_sources/`是原始审计脚本及环境特定runner，保留原文并用.gdignore排除导入，**不要作为当前可直接运行的入口**；原capture脚本同样只作证据。可执行适配会另置portable并产生新的烟测结果，不能把适配结果伪装成原293运行。

清单`EXPORT_MANIFEST_ORIGINAL.json`逐项绑定93个原证据字节；不包含fixture运行源码、资产、.godot、XDG或用户存档。CUA箭头physical_keycode=0的限制、测试驱动一次早期parse失败及后来纠正均保留；最终通过不等于实体键盘/游戏手柄/跨平台无障碍认证。

最终增补：`production_addendum/`已核对root新8056、生产637与三图，原始93清单不变；新增23文件由`EXPORT_MANIFEST_ADDITIONS.json`绑定。可执行入口为 `GODOT=/path/to/godot-4.7.2 bash tests/keyboard_navigation_audit/portable/run_portable.sh "$PWD" /tmp/keyboard-audit-output`。路径适配后实际生产新293烟测在portable_smoke_results_final，75hash不变；不累计进原293。portable桌面observer未重新GUI运行，不能当额外原生证据。

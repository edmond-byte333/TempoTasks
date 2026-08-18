# TempoTasks

TempoTasks 是一个仅在本机保存数据的 macOS 菜单栏任务工具。按 `Control + Space` 唤出或隐藏面板，输入任务后可选择今天、明天或自定义日期。

## 使用

1. 运行 `./scripts/build-app.sh`。
2. 打开 `build/TempoTasks.app`。
3. 按 `Control + Space` 唤出面板。

如果快捷键已被 macOS 的输入法切换占用，应用会在面板与菜单栏菜单中提示快捷键不可用。此时可先在“系统设置 → 键盘 → 键盘快捷键 → 输入法”中取消对应快捷键。

任务数据通过 SwiftData 保存在当前 Mac 上，不读取系统日历，也不上传云端。


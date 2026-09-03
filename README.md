# TempoTasks

TempoTasks 是一个仅在本机保存数据的 macOS 菜单栏任务工具。按 `Control + Command + Space` 唤出或隐藏面板，输入任务后可选择今天、明天或自定义日期。

## 使用

1. 运行 `./scripts/build-app.sh`。
2. 打开 `build/TempoTasks.app`。
3. 按 `Control + Command + Space` 唤出面板。

## 修改快捷键

在面板左下角「快捷键」一栏点击当前键帽，然后按下新的组合即可。按 Escape 放弃修改，点击右侧的回转箭头恢复默认。

新组合至少要包含 Control、Option 或 Command 其中之一，否则普通打字会误触发。macOS 要求全局快捷键必须带一个实体主键，所以只按住修饰键（例如仅 Control + Command）无法注册。

如果某个组合已被系统或其他应用占用，面板与菜单栏都会标记为「被占用」，此时仍可点击菜单栏图标打开面板。旧版默认的 `Control + Space` 常被 macOS 的输入法切换占用，可在「系统设置 → 键盘 → 键盘快捷键 → 输入法」中取消对应快捷键后再使用。

快捷键保存在本机偏好设置中，和任务数据一样不会上传。

## 数据

任务数据通过 SwiftData 保存在当前 Mac 上，不读取系统日历，也不上传云端。

# TempoTasks 窗口拖动与会话位置实施计划

## 1. 独立位置状态

- 新增 `PanelPositionMemory`，只保存内存 frame 和拖动起点。
- 新增纯计算方法：默认顶部居中、完整可见判断、约束到 `visibleFrame`。
- 只有成对的 `beginDrag` / `endDrag` 且 frame 变化时写入会话位置。
- 为未开始拖动、未移动、屏幕约束和屏幕失效添加单元测试。

## 2. 原生拖动表面

- 新增 `WindowDragSurface`，用 `NSViewRepresentable` 接收 `mouseDown`。
- 调用开始回调后执行 `NSWindow.performDrag(with:)`，返回后发送原 frame 与新 frame。
- 仅覆盖品牌区和标题区，不覆盖交互控件。

## 3. PanelController 接入

- 持有 `PanelPositionMemory`，将拖动开始/结束闭包传给 SwiftUI 根视图。
- 显示前：有效会话 frame 则恢复；否则按鼠标所在屏幕顶部居中。
- 拖动结束：约束 frame，应用并写入内存。
- 监听屏幕参数变化；显示时立即校验，隐藏时下次显示校验。
- 不写 `UserDefaults`，App 退出后状态随 Controller 销毁。

## 4. 验证和交付

- 运行全部单元测试和 Release 构建。
- 实际拖动品牌区与标题区，确认输入框和日期按钮不受影响。
- 确认拖动后隐藏/重显保持位置。
- 终止并重启测试实例，确认恢复默认顶部中央。
- 重新生成并签名 `build/TempoTasks.app`。

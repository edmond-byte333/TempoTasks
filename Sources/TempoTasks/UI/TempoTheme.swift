import SwiftUI

enum TempoTheme {
    static let canvas = Color(red: 7 / 255, green: 8 / 255, blue: 10 / 255)
    static let surface = Color(red: 16 / 255, green: 17 / 255, blue: 17 / 255)
    static let raised = Color(red: 27 / 255, green: 28 / 255, blue: 30 / 255)
    static let primaryText = Color.white.opacity(0.88)
    static let secondaryText = Color.white.opacity(0.64)
    static let completedText = Color.white.opacity(0.38)
    static let hairline = Color.white.opacity(0.06)
    static let strongBorder = Color.white.opacity(0.10)
    static let focusBlue = Color(red: 85 / 255, green: 179 / 255, blue: 1)
    static let completionCoral = Color(red: 1, green: 99 / 255, blue: 99 / 255)
    static let successGreen = Color(red: 95 / 255, green: 201 / 255, blue: 146 / 255)
}

extension Notification.Name {
    static let tempoFocusInput = Notification.Name("TempoTasks.focusInput")
}

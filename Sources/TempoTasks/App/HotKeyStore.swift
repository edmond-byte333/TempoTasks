import Foundation

/// 把用户自定义的快捷键存到本机偏好设置里，和任务数据一样不出本机。
struct HotKeyStore {
    private static let key = "TempoTasks.hotKeyCombo"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 读不到或数据损坏时回落到默认组合，不让应用因为一条偏好设置起不来。
    func load() -> HotKeyCombo {
        guard let data = defaults.data(forKey: Self.key),
              let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data)
        else {
            return .default
        }
        return combo
    }

    func save(_ combo: HotKeyCombo) {
        guard let data = try? JSONEncoder().encode(combo) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func reset() {
        defaults.removeObject(forKey: Self.key)
    }
}

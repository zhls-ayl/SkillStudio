import SwiftUI

// MARK: - 日期格式化扩展

extension String {
    /// 把 ISO 8601 时间戳转换成更适合展示的格式。
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: self) else { return self }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - URL 扩展

extension URL {
    /// 返回使用 `~` 缩写后的路径表示，便于在 UI 中展示。
    var tildeAbbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - View 扩展

extension View {
    /// 条件 modifier。
    /// 用法示例：`.if(condition) { view in view.foregroundColor(.red) }`
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

import Foundation

/// `VersionComparator` 是一个用于比较版本号的 utility enum。
///
/// 这里把 `enum` 当作 namespace 使用，与 `Constants.swift` 的风格保持一致。
/// 当前支持的版本格式包括：标准 `major.minor.patch`、可选 `v` 前缀，以及 pre-release 后缀忽略。
enum VersionComparator {

    /// 把版本字符串解析成整数数组。
    ///
    /// 解析步骤包括：去掉 `v` 前缀、去掉 pre-release 后缀，再按 `.` 拆分并转成整数。
    static func parse(_ version: String) -> [Int] {
        // 这里使用 Swift 的字符串链式处理来逐步清洗输入。
        var cleaned = version

        // 如果存在 `v` / `V` 前缀，就先去掉；注意 `dropFirst()` 返回的是 `Substring`。
        if cleaned.hasPrefix("v") || cleaned.hasPrefix("V") {
            cleaned = String(cleaned.dropFirst())
        }

        // 如果包含 `-`，说明后面是 pre-release 后缀，这里只保留前半部分。
        if let dashIndex = cleaned.firstIndex(of: "-") {
            cleaned = String(cleaned[cleaned.startIndex..<dashIndex])
        }

        // `compactMap` 会把无法转换成 `Int` 的片段自动过滤掉。
        return cleaned.split(separator: ".").compactMap { Int($0) }
    }

    /// 比较两个版本号，判断 `latest` 是否比 `current` 更新。
    ///
    /// 比较规则是按 major → minor → patch 逐段对比；如果某一方段数不足，则缺失段按 `0` 处理。
    static func isNewer(current: String, latest: String) -> Bool {
        let currentParts = parse(current)
        let latestParts = parse(latest)

        // Use maximum segment count of two versions as comparison length
        // max() is Swift global function (similar to Math.max)
        let count = max(currentParts.count, latestParts.count)

        for i in 0..<count {
            // If a version has insufficient segments, pad with 0
            // e.g. 3rd segment of "1.2" is treated as 0, equivalent to "1.2.0"
            // Ternary operator consistent with Java/Go/Python syntax
            let c = i < currentParts.count ? currentParts[i] : 0
            let l = i < latestParts.count ? latestParts[i] : 0

            if l > c { return true }   // latest has larger segment, indicating update
            if l < c { return false }  // latest has smaller segment, indicating old version
            // l == c continue to compare next segment
        }

        // All segments equal, versions are same, not an update
        return false
    }
}

import Foundation

/// `RepositoryScanCache` 持久化 custom repository 的轻量扫描索引。
///
/// 设计目标：
/// - 只缓存列表浏览所需的 skill 摘要，不缓存完整 Markdown 正文
/// - 以仓库当前 `HEAD commit` 作为缓存命中条件，未变更时直接复用
/// - 将缓存保持在 SkillsMaster 私有目录下，不影响 lock file 兼容性
actor RepositoryScanCache {

    private struct CacheFile: Codable {
        var repositories: [String: RepositoryEntry]
    }

    private struct RepositoryEntry: Codable {
        var repoID: String
        var localPath: String
        var scanHiddenPaths: Bool
        var headCommit: String
        var scannedAt: String
        var skills: [CachedSkill]
    }

    private struct CachedSkill: Codable {
        var id: String
        var folderPath: String
        var skillMDPath: String
        var metadata: SkillMetadata
    }

    static let defaultPath: URL = {
        let expanded = NSString(string: Constants.repositoryScanCachePath).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }()

    private let filePath: URL
    private var entries: [String: RepositoryEntry] = [:]
    private var isLoaded = false

    init(filePath: URL = RepositoryScanCache.defaultPath) {
        self.filePath = filePath
    }

    func getSkills(for repo: SkillRepository, headCommit: String) -> [GitService.DiscoveredSkill]? {
        ensureLoaded()

        guard let entry = entries[repo.id.uuidString],
              entry.localPath == repo.localPath,
              entry.scanHiddenPaths == repo.scanHiddenPaths,
              entry.headCommit == headCommit else {
            return nil
        }

        return entry.skills.map {
            GitService.DiscoveredSkill(
                id: $0.id,
                folderPath: $0.folderPath,
                skillMDPath: $0.skillMDPath,
                metadata: $0.metadata,
                markdownBody: ""
            )
        }
    }

    func saveSkills(_ skills: [GitService.DiscoveredSkill], for repo: SkillRepository, headCommit: String) throws {
        ensureLoaded()

        let cachedSkills = skills.map {
            CachedSkill(
                id: $0.id,
                folderPath: $0.folderPath,
                skillMDPath: $0.skillMDPath,
                metadata: $0.metadata
            )
        }

        entries[repo.id.uuidString] = RepositoryEntry(
            repoID: repo.id.uuidString,
            localPath: repo.localPath,
            scanHiddenPaths: repo.scanHiddenPaths,
            headCommit: headCommit,
            scannedAt: ISO8601DateFormatter().string(from: Date()),
            skills: cachedSkills
        )

        try saveToDisk()
    }

    func remove(repoID: UUID) throws {
        ensureLoaded()
        entries.removeValue(forKey: repoID.uuidString)
        try saveToDisk()
    }

    private func saveToDisk() throws {
        let cacheFile = CacheFile(repositories: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(cacheFile)

        let parentDir = filePath.deletingLastPathComponent()
        let fm = FileManager.default
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        try data.write(to: filePath, options: .atomic)
    }

    private func ensureLoaded() {
        guard !isLoaded else { return }
        isLoaded = true

        let fm = FileManager.default
        guard fm.fileExists(atPath: filePath.path) else { return }

        do {
            let data = try Data(contentsOf: filePath)
            let cacheFile = try JSONDecoder().decode(CacheFile.self, from: data)
            entries = cacheFile.repositories
        } catch {
            entries = [:]
        }
    }
}

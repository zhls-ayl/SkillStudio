import Foundation

/// MigrationManager handles one-time data migration from old paths to new paths
///
/// When SkillStudio upgraded its canonical storage from ~/.agents/skills/ to ~/.skillstudio/skills/,
/// existing users need their data migrated automatically on first launch.
///
/// Migration scope:
/// - Skill directories:        ~/.agents/skills/<name>/     → ~/.skillstudio/skills/<name>/
/// - Cache file:               ~/.agents/.skillstudio-cache.json → ~/.skillstudio/.skillstudio-cache.json
/// - Repos config:             ~/.agents/.skillstudio-repos.json → ~/.skillstudio/.skillstudio-repos.json
/// - Repos clones:             ~/.agents/repos/             → ~/.skillstudio/repos/
/// - Agent symlinks:           updated to point to new canonical path
/// - Lock file:                NOT migrated (stays at ~/.agents/.skill-lock.json, shared with npx skills)
///
/// Uses `enum` as a namespace (no instances) with static methods.
/// The migration is idempotent — safe to run multiple times.
enum MigrationManager {

    // MARK: - Old paths (before migration)

    /// Old canonical skills directory
    private static let oldSkillsDir: URL = {
        let path = NSString(string: "~/.agents/skills").expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()

    /// Old cache file
    private static let oldCachePath: URL = {
        let path = NSString(string: "~/.agents/.skillstudio-cache.json").expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()

    /// Old repos config file
    private static let oldReposConfigPath: URL = {
        let path = NSString(string: "~/.agents/.skillstudio-repos.json").expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()

    /// Old repos clone directory
    private static let oldReposDir: URL = {
        let path = NSString(string: "~/.agents/repos").expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()

    // MARK: - New paths (after migration)

    /// New canonical skills directory (matches AgentType.sharedSkillsDirectoryURL)
    private static let newSkillsDir = AgentType.sharedSkillsDirectoryURL

    /// New SkillStudio base directory
    private static let newBaseDir: URL = {
        let path = NSString(string: "~/.skillstudio").expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()

    /// New cache file path (matches CommitHashCache.defaultPath)
    private static let newCachePath = CommitHashCache.defaultPath

    /// New repos config path
    private static let newReposConfigPath: URL = {
        let path = NSString(string: Constants.skillReposConfigPath).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()

    /// New repos clone directory
    private static let newReposDir: URL = {
        let path = NSString(string: Constants.reposBasePath).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }()

    // MARK: - Public API

    /// Perform migration if needed. Safe to call multiple times (idempotent).
    ///
    /// Checks whether old paths contain data that should be moved to new paths.
    /// Skips individual steps if source doesn't exist or destination already has data.
    static func migrateIfNeeded() {
        let fm = FileManager.default

        // Quick check: if old skills directory doesn't exist, nothing to migrate
        // (other files like cache/repos are secondary — if skills dir is gone, likely a fresh install)
        guard fm.fileExists(atPath: oldSkillsDir.path) else { return }

        // Ensure new base directory exists (~/.skillstudio/)
        try? fm.createDirectory(at: newBaseDir, withIntermediateDirectories: true)

        // 1. Migrate skill directories (real directories only, not symlinks)
        migrateSkillDirectories()

        // 2. Fix Agent symlinks to point to new canonical path
        fixAgentSymlinks()

        // 3. Migrate SkillStudio private files
        moveFileIfNeeded(from: oldCachePath, to: newCachePath)
        moveFileIfNeeded(from: oldReposConfigPath, to: newReposConfigPath)
        moveDirIfNeeded(from: oldReposDir, to: newReposDir)
    }

    // MARK: - Private Helpers

    /// Move skill directories from old canonical location to new location.
    /// Only moves real directories (not symlinks) — symlinks in ~/.agents/skills/ are
    /// typically created by agents like Codex and should be left alone.
    private static func migrateSkillDirectories() {
        let fm = FileManager.default

        // Ensure new skills directory exists
        try? fm.createDirectory(at: newSkillsDir, withIntermediateDirectories: true)

        guard let contents = try? fm.contentsOfDirectory(
            at: oldSkillsDir,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for itemURL in contents {
            let name = itemURL.lastPathComponent
            let newURL = newSkillsDir.appendingPathComponent(name)

            // Skip if already exists at new location (idempotent)
            guard !fm.fileExists(atPath: newURL.path) else { continue }

            // Only move real directories (not symlinks)
            // Symlinks in ~/.agents/skills/ may belong to agents that read this directory
            guard !SymlinkManager.isSymlink(at: itemURL) else { continue }

            // Move directory to new location
            // moveItem is atomic on the same filesystem (similar to rename() in POSIX)
            try? fm.moveItem(at: itemURL, to: newURL)
        }
    }

    /// Fix symlinks in all Agent skills directories that point to old canonical path.
    /// Recreates them to point to the new canonical path instead.
    private static func fixAgentSymlinks() {
        let fm = FileManager.default

        for agentType in AgentType.allCases {
            let agentDir = agentType.skillsDirectoryURL
            guard fm.fileExists(atPath: agentDir.path) else { continue }

            guard let contents = try? fm.contentsOfDirectory(
                at: agentDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for itemURL in contents {
                guard SymlinkManager.isSymlink(at: itemURL) else { continue }

                // Read one-level symlink destination (not recursive resolve)
                // We want to check if the immediate target is in the old canonical dir
                guard let destination = try? fm.destinationOfSymbolicLink(atPath: itemURL.path) else {
                    continue
                }

                // Resolve relative path to absolute
                let absoluteDest: String
                if destination.hasPrefix("/") {
                    absoluteDest = destination
                } else {
                    // Relative symlink — resolve against the symlink's parent directory
                    absoluteDest = agentDir.appendingPathComponent(destination).standardized.path
                }

                // Check if symlink points to old canonical directory
                let oldPrefix = oldSkillsDir.path
                guard absoluteDest.hasPrefix(oldPrefix) else { continue }

                // Extract skill name and compute new target
                let skillName = itemURL.lastPathComponent
                let newTarget = newSkillsDir.appendingPathComponent(skillName)

                // Only relink if new target exists (migration step 1 moved it there)
                guard fm.fileExists(atPath: newTarget.path) else { continue }

                // Remove old symlink and create new one pointing to new canonical path
                try? fm.removeItem(at: itemURL)
                try? fm.createSymbolicLink(at: itemURL, withDestinationURL: newTarget)
            }
        }
    }

    /// Move a single file from old path to new path if source exists and destination does not.
    private static func moveFileIfNeeded(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return }
        guard !fm.fileExists(atPath: destination.path) else { return }

        // Ensure parent directory exists
        let parent = destination.deletingLastPathComponent()
        try? fm.createDirectory(at: parent, withIntermediateDirectories: true)
        try? fm.moveItem(at: source, to: destination)
    }

    /// Move a directory from old path to new path if source exists and destination does not.
    private static func moveDirIfNeeded(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return }
        guard !fm.fileExists(atPath: destination.path) else { return }

        // Ensure parent directory exists
        let parent = destination.deletingLastPathComponent()
        try? fm.createDirectory(at: parent, withIntermediateDirectories: true)
        try? fm.moveItem(at: source, to: destination)
    }
}

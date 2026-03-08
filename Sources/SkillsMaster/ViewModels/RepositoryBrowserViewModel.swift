import Foundation

/// RepositoryBrowserViewModel manages the state for browsing a single custom repository.
///
/// Each configured repository gets its own instance of this ViewModel, stored in
/// ContentView's `repoVMs: [UUID: RepositoryBrowserViewModel]` dictionary.
///
/// Responsibilities:
/// - Load the list of Skills available in the cloned repository (via RepositoryManager.scanSkills)
/// - Track search text for local filtering (no network request needed — all data is local)
/// - Trigger installation of a selected skill from already-synced local repository data
/// - Expose sync status so the UI can show a spinner while a git pull is in progress
/// - Lazy-load full SKILL.md content only for the selected skill
///
/// @MainActor @Observable follows the same pattern as RegistryBrowserViewModel.
@MainActor
@Observable
final class RepositoryBrowserViewModel {

    // MARK: - State

    /// The repository this ViewModel represents.
    /// Must stay mutable so lastSyncedAt/name updates propagate to UI.
    var repository: SkillRepository

    /// All skills discovered in the cloned repository (unfiltered)
    var allSkills: [GitService.DiscoveredSkill] = []

    /// Skills shown in the list after applying searchText filter
    var displayedSkills: [GitService.DiscoveredSkill] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return allSkills }
        return allSkills.filter { skill in
            skill.metadata.name.localizedCaseInsensitiveContains(text)
                || skill.metadata.description.localizedCaseInsensitiveContains(text)
        }
    }

    /// Search text for filtering the skill list (no debounce needed — filtering is synchronous)
    var searchText = ""

    /// Whether the initial skill scan is running (shows ProgressView in the list)
    var isLoading = false

    /// Human-readable loading message shown when the repository view is waiting.
    var loadingMessage: String {
        if isSyncing && !repository.isCloned {
            return "Synchronizing repository…"
        }
        if isSyncing {
            return "Refreshing repository index…"
        }
        return "Indexing repository…"
    }

    /// Error message (nil = no error)
    var errorMessage: String?

    /// Informational notice for repository scan behavior, e.g. cache bypass.
    var scanNoticeMessage: String?

    /// Currently selected skill (drives the detail pane in ContentView)
    var selectedSkillID: String? {
        didSet {
            guard oldValue != selectedSkillID else { return }
            resetSelectedSkillContent()
        }
    }

    /// Selected skill object resolved from `selectedSkillID`.
    ///
    /// This is consumed by ContentView's detail column for custom repositories.
    var selectedSkill: GitService.DiscoveredSkill? {
        guard let id = selectedSkillID else { return nil }
        return allSkills.first { $0.id == id }
    }

    /// Lazily loaded full content for the selected skill.
    var selectedSkillContent: SkillMDParser.ParseResult?

    /// Whether the detail view is loading the selected skill's full content.
    var isLoadingSelectedSkillContent = false

    /// Error message for selected skill content loading.
    var selectedSkillContentError: String?

    /// Install sheet ViewModel — non-nil triggers the install sheet.
    /// Same pattern as RegistryBrowserViewModel.installVM.
    var installVM: SkillInstallViewModel?

    /// Current sync status for this repository.
    var syncStatus: SkillRepository.SyncStatus {
        skillManager.repoSyncStatuses[repository.id] ?? .idle
    }

    /// Whether this repository is currently syncing.
    var isSyncing: Bool {
        if case .syncing = syncStatus { return true }
        return false
    }

    /// Whether local installation is allowed now.
    /// Requires: local clone exists + not currently syncing.
    var canInstallFromLocal: Bool {
        repository.isCloned && !isSyncing
    }

    /// Human-readable reason when install is disabled.
    var installDisabledReason: String? {
        if isSyncing { return "Repository 正在同步，请稍候。" }
        if !repository.isCloned {
            return "安装前需要先同步 Repository。"
        }
        return nil
    }

    // MARK: - Private

    private let skillManager: SkillManager
    private var contentCache: [String: SkillMDParser.ParseResult] = [:]
    private var loadingContentSkillID: String?

    // MARK: - Init

    init(repository: SkillRepository, skillManager: SkillManager) {
        self.repository = repository
        self.skillManager = skillManager
    }

    // MARK: - Public API

    /// Called when the RepositoryBrowserView first appears.
    ///
    /// Scans the local clone for SKILL.md files. This is a purely local operation —
    /// no network requests are made. The actual git pull (sync) is triggered separately
    /// by the user or on app startup.
    func onAppear() async {
        await loadSkills()
    }

    /// Refresh repository metadata from SkillManager (name, lastSyncedAt, enabled state, etc.).
    /// ContentView calls this whenever skillManager.repositories changes.
    func updateRepository(_ repository: SkillRepository) {
        self.repository = repository
    }

    /// Reload the skill list from the local clone directory.
    ///
    /// Called after a sync completes (to pick up any newly pulled skills)
    /// and on initial appear.
    ///
    /// Uses `RepositoryManager.scanSkills(in:)` which calls `GitService.scanSkillsInRepo`
    /// on the actor — this keeps file I/O off the main thread.
    ///
    /// - Parameter overrideError: If provided, this message is shown instead of the
    ///   generic "not yet synced" message.
    func loadSkills(overrideError: String? = nil) async {
        isLoading = true
        if overrideError == nil { errorMessage = nil }

        let scanResult = await skillManager.repositoryManager.scanSkillsResult(in: repository)
        await applyScanResult(scanResult, overrideError: overrideError)
    }

    func applyScanResult(_ scanResult: RepositoryManager.ScanResult, overrideError: String? = nil) async {
        contentCache.removeAll()
        allSkills = scanResult.skills
        scanNoticeMessage = scanResult.cacheStatus.noticeMessage
        isLoading = false

        if let selectedSkillID,
           let refreshedSelectedSkill = allSkills.first(where: { $0.id == selectedSkillID }) {
            contentCache.removeValue(forKey: selectedSkillID)
            await loadContent(for: refreshedSelectedSkill, force: true)
        } else if selectedSkillID != nil {
            resetSelectedSkillContent()
        }

        if let override = overrideError {
            errorMessage = override
        } else if !repository.isCloned && allSkills.isEmpty && !isSyncing {
            errorMessage = "Repository 尚未同步，请先点击 Sync 按钮完成 clone。"
        }
    }

    /// Load the full `SKILL.md` content for the selected skill on demand.
    func loadContent(for skill: GitService.DiscoveredSkill, force: Bool = false) async {
        if !force, let cached = contentCache[skill.id] {
            selectedSkillContent = cached
            selectedSkillContentError = nil
            isLoadingSelectedSkillContent = false
            return
        }
        if loadingContentSkillID == skill.id {
            return
        }

        selectedSkillContent = nil
        selectedSkillContentError = nil
        isLoadingSelectedSkillContent = true
        loadingContentSkillID = skill.id
        let targetSkillID = skill.id

        do {
            let content = try await skillManager.repositoryManager.loadSkillContent(
                in: repository,
                skillMDPath: skill.skillMDPath
            )

            guard selectedSkillID == targetSkillID else { return }
            contentCache[targetSkillID] = content
            selectedSkillContent = content
        } catch {
            guard selectedSkillID == targetSkillID else { return }
            selectedSkillContentError = error.localizedDescription
        }

        if selectedSkillID == targetSkillID {
            isLoadingSelectedSkillContent = false
            loadingContentSkillID = nil
        }
    }

    /// Trigger installation of a discovered skill from the already-synced local repository.
    ///
    /// - Parameter skill: The discovered skill to install
    func installSkill(_ skill: GitService.DiscoveredSkill) {
        if let reason = installDisabledReason {
            errorMessage = reason
            return
        }
        guard !allSkills.isEmpty else {
            errorMessage = "当前没有可安装的 Skills，请先同步后重试。"
            return
        }

        let vm = SkillInstallViewModel(skillManager: skillManager)
        vm.prepareForLocalRepository(
            repoDir: URL(fileURLWithPath: repository.localPath),
            repoURL: repository.repoURL,
            repoSource: sourceIdentifier(),
            discoveredSkills: allSkills,
            targetSkillId: skill.id
        )
        installVM = vm
    }

    /// Check if a discovered skill is already installed locally.
    ///
    /// Matches by skill ID (directory name). The skill is considered installed
    /// if SkillManager already has a Skill with the same ID in its scanned list.
    func isInstalled(_ skill: GitService.DiscoveredSkill) -> Bool {
        skillManager.skills.contains { $0.id == skill.id }
    }

    /// Sync this repository (git pull or clone).
    ///
    /// Delegates to SkillManager.syncRepository which updates repoSyncStatuses
    /// (observed by SidebarView for the spinner indicator).
    ///
    /// Sync result handling is centralized in `handleSyncStatusChange(_:)`,
    /// which is driven by SkillManager's repoSyncStatuses state changes.
    /// This avoids duplicate reload paths (manual sync completion + status observer).
    func sync() async {
        errorMessage = nil
        await skillManager.syncRepository(id: repository.id)
    }

    /// React to repository sync status transitions.
    ///
    /// Best-practice state flow:
    /// - `sync()` triggers only the domain action (SkillManager.syncRepository)
    /// - UI data reload is triggered from the single source of truth (`repoSyncStatuses`)
    ///
    /// This avoids writing list data from multiple call paths and reduces List/NSTableView
    /// reentrancy risk during sync operations.
    ///
    /// - Parameter newStatus: Latest status from SkillManager.repoSyncStatuses[repository.id]
    func handleSyncStatusChange(_ newStatus: SkillRepository.SyncStatus?) async {
        guard let newStatus else { return }

        switch newStatus {
        case .idle:
            break
        case .syncing:
            isLoading = true
        case .success:
            await loadSkills()
        case .error(let gitError):
            isLoading = false
            errorMessage = "同步失败：\(gitError)"
        }
    }

    private func resetSelectedSkillContent() {
        selectedSkillContent = nil
        selectedSkillContentError = nil
        isLoadingSelectedSkillContent = false
        loadingContentSkillID = nil
    }

    private func sourceIdentifier() -> String {
        let trimmed = repository.repoURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.lowercased().hasPrefix("git@"),
           let colonIdx = trimmed.firstIndex(of: ":") {
            var source = String(trimmed[trimmed.index(after: colonIdx)...])
            if source.hasSuffix(".git") {
                source = String(source.dropLast(4))
            }
            return source
        }

        if let components = URLComponents(string: trimmed) {
            var path = components.path
            while path.hasPrefix("/") { path.removeFirst() }
            while path.hasSuffix("/") { path.removeLast() }
            if path.hasSuffix(".git") {
                path = String(path.dropLast(4))
            }
            if !path.isEmpty { return path }
        }

        return repository.localSlug
    }
}

import Foundation

/// `SkillInstallViewModel` 负责 F10（one-click install）弹窗的状态与流程编排。
///
/// 当前安装流程分两步：
/// 1. 用户输入 GitHub repository URL → shallow clone → 扫描可用 Skills → 展示列表
/// 2. 用户选择 Skills 与 Agents → 执行安装 → 完成
///
/// 这里使用 `@MainActor` 保证 UI state 只在 main thread 更新，
/// 使用 `@Observable` 让属性变化自动驱动 SwiftUI 刷新。
@MainActor
@Observable
/// `Identifiable` 要求提供唯一 `id`，这样 `\.sheet(item:)` 就可以根据 item 是否为 `nil` 判断弹窗展示状态。
/// 相比 `\.sheet(isPresented:)` 再额外维护一份 `@State`，这种写法更不容易出现双状态同步时序问题。
final class SkillInstallViewModel: Identifiable {

    /// 唯一标识符，是 `Identifiable` 协议要求的属性。
    /// 每个新的 `ViewModel` 实例都会自动生成一个新的 `UUID`。
    let id = UUID()

    // MARK: - Phase Enum

    /// 安装流程阶段（finite state machine）。
    enum Phase: Equatable {
        /// 初始阶段：等待用户输入 URL。
        case inputURL
        /// 正在 clone repository 并扫描 skills。
        case fetching
        /// 已发现 skills，等待用户选择。
        case selectSkills
        /// 正在安装用户选中的 skills。
        case installing
        /// 安装完成。
        case completed
        /// 出现错误，并附带错误信息。
        case error(String)

        // 手动实现 `Equatable`，确保不同阶段的比较行为符合当前 UI 预期。
        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.inputURL, .inputURL),
                 (.fetching, .fetching),
                 (.selectSkills, .selectSkills),
                 (.installing, .installing),
                 (.completed, .completed):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    /// 安装来源模式：
    /// - `remoteClone`：先 clone 再安装
    /// - `localRepository`：从已同步的本地 repository 安装
    private enum SourceMode {
        case remoteClone
        case localRepository
    }

    // MARK: - State

    /// 用户输入的 repository 地址（支持 `owner/repo` 或完整 URL）。
    var repoURLInput = ""

    /// 根据来源模式动态生成的 sheet 标题。
    var sheetTitle: String {
        switch sourceMode {
        case .remoteClone:
            return "Install Skills from GitHub"
        case .localRepository:
            return "Install Skills from Custom Repository"
        }
    }

    /// 当前是否处于本地 custom repository 模式。
    var isLocalSource: Bool { sourceMode == .localRepository }

    /// F09：当 install sheet 打开时，是否自动触发 fetch。
    /// 这个标记主要用于从 Registry Browser 跳转安装时的自动扫描。
    var autoFetch = false

    /// F09：扫描完成后需要预选中的 target skill ID。
    /// 从 Registry Browser 发起安装时，只会预选当前点击的 skill。
    var targetSkillId: String?

    /// 当前安装流程所处的阶段。
    var phase: Phase = .inputURL

    /// 当前 repository 中扫描到的全部 skills。
    var discoveredSkills: [GitService.DiscoveredSkill] = []

    /// 用户选择安装的 skill 名称集合。
    /// Set provides O(1) lookup, similar to Java's HashSet
    var selectedSkillNames: Set<String> = []

    /// 用户选择的目标 Agent 集合（默认选中 `Claude Code`）。
    var selectedAgents: Set<AgentType> = [.claudeCode]

    /// 已安装 skill 名称集合，用于列表中的 “already installed” 标记。
    var alreadyInstalledNames: Set<String> = []

    /// 进度提示信息。
    var progressMessage = ""

    /// 已成功安装的 skill 数量。
    var installedCount = 0

    /// Merged and deduplicated repo history (from lock file + scan history)
    /// Loaded asynchronously via loadHistory() after ViewModel creation
    var repoHistory: [(source: String, sourceUrl: String)] = []

    // MARK: - Dependencies

    /// SkillManager reference, used to execute installation and check installed status
    private let skillManager: SkillManager

    /// Git operation service
    private let gitService = GitService()

    /// Cloned temporary directory URL (persisted between fetch and install, cleaned up when sheet closes)
    private var tempRepoDir: URL?
    /// Whether tempRepoDir should be deleted on cleanup.
    /// Local custom repository mode points to persistent local clone and must NOT be deleted.
    private var ownsTempRepoDir = false

    /// Normalized repository URL and source identifier
    private var normalizedRepoURL: String = ""
    private var normalizedSource: String = ""
    /// Source type written to lock entry (e.g. github/custom)
    private var lockSourceType: String = "github"
    private var sourceMode: SourceMode = .remoteClone

    // MARK: - Init

    init(skillManager: SkillManager) {
        self.skillManager = skillManager
    }

    // MARK: - Actions

    /// Load repo history (merged from lock file + scan history)
    ///
    /// Called from the View's .task modifier (not in init, because init is synchronous
    /// while getRepoHistory is async and requires await).
    /// .task runs async code when the view first appears, similar to Android's onResume + coroutine
    func loadHistory() async {
        repoHistory = await skillManager.getRepoHistory()
    }

    /// Select a history entry: auto-fill URL input and trigger Scan
    ///
    /// Called when the user taps a row in the Install Sheet's history list.
    /// Uses the source (owner/repo) format as input — fetchRepository() will normalize it internally.
    ///
    /// - Parameter source: Repo source identifier (e.g. "crossoverJie/skills")
    /// - Parameter sourceUrl: Full repo URL (e.g. "https://github.com/crossoverJie/skills.git")
    func selectHistoryRepo(source: String, sourceUrl: String) async {
        // Use source format (owner/repo) as input; fetchRepository normalizes it internally
        repoURLInput = source
        await fetchRepository()
    }

    /// Step 1: Clone repository and scan for skills
    ///
    /// Execution flow:
    /// 1. Normalize URL (supports "owner/repo" and full URL formats)
    /// 2. Check if git is available
    /// 3. Shallow clone repository
    /// 4. Scan SKILL.md files
    /// 5. Mark already installed skills
    /// 6. Transition to selection phase
    func fetchRepository() async {
        sourceMode = .remoteClone
        lockSourceType = "github"
        phase = .fetching
        progressMessage = "Validating URL..."

        do {
            // 1. Normalize URL
            let (repoURL, source) = try GitService.normalizeRepoURL(repoURLInput)
            normalizedRepoURL = repoURL
            normalizedSource = source

            // 2. Check git
            progressMessage = "Checking git..."
            let gitAvailable = await gitService.checkGitAvailable()
            guard gitAvailable else {
                phase = .error("Git is not installed. Please install git first.")
                return
            }

            // 3. Shallow clone
            progressMessage = "Cloning repository..."
            let repoDir = try await gitService.shallowClone(repoURL: repoURL)
            tempRepoDir = repoDir
            ownsTempRepoDir = true

            // 4. Scan skills
            progressMessage = "Scanning skills..."
            let discovered = await gitService.scanSkillsInRepo(repoDir: repoDir)

            guard !discovered.isEmpty else {
                phase = .error("No skills found in this repository.")
                return
            }

            discoveredSkills = discovered

            // 5. Mark already installed skills
            alreadyInstalledNames = Set(skillManager.skills.map(\.id))

            // Pre-select skills based on context:
            // - F09 Registry install (targetSkillId is set): only select the specific target skill
            // - Manual install (targetSkillId is nil): select all uninstalled skills
            if let targetId = targetSkillId {
                // From Registry Browser: only select the specific skill the user clicked
                // Filter to ensure the target skill exists in the repo and isn't already installed
                selectedSkillNames = Set(
                    discovered.map(\.id).filter { $0 == targetId && !alreadyInstalledNames.contains($0) }
                )
            } else {
                // Manual install: select all uninstalled skills by default
                selectedSkillNames = Set(discovered.map(\.id).filter { !alreadyInstalledNames.contains($0) })
            }

            // Save scan history (so this repo appears in "Recent Repositories" next time)
            await skillManager.saveRepoHistory(source: normalizedSource, sourceUrl: normalizedRepoURL)

            // 6. Transition to selection phase
            phase = .selectSkills
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// Step 2: Install selected skills
    ///
    /// Install selected skills one by one, updating progress message
    func installSelected() async {
        guard !selectedSkillNames.isEmpty else { return }
        guard let repoDir = tempRepoDir else {
            phase = .error("Repository data not available. Please scan again.")
            return
        }

        phase = .installing
        installedCount = 0
        let total = selectedSkillNames.count

        for skill in discoveredSkills where selectedSkillNames.contains(skill.id) {
            progressMessage = "Installing \(skill.id) (\(installedCount + 1)/\(total))..."

            do {
                try await skillManager.installSkill(
                    from: repoDir,
                    skill: skill,
                    repoSource: normalizedSource,
                    repoURL: normalizedRepoURL,
                    sourceType: lockSourceType,
                    targetAgents: selectedAgents
                )
                installedCount += 1
            } catch {
                // Single skill installation failure doesn't block other skills
                // Error info is recorded (can be extended to show detailed error list in the future)
                continue
            }
        }

        phase = .completed
    }

    /// Clean up temporary directory (called when sheet closes)
    ///
    /// Use Task to wrap actor method calls because cleanup is synchronous but needs to await actor methods
    func cleanup() {
        if let tempRepoDir, ownsTempRepoDir {
            let dir = tempRepoDir
            self.tempRepoDir = nil
            Task {
                await gitService.cleanupTempDirectory(dir)
            }
        } else {
            tempRepoDir = nil
        }
        ownsTempRepoDir = false
    }

    /// Toggle selection state of a skill
    /// symmetricDifference is Set's symmetric difference operation: remove if exists, add if not
    /// Similar to Java Set's toggle operation
    func toggleSkillSelection(_ skillName: String) {
        if selectedSkillNames.contains(skillName) {
            selectedSkillNames.remove(skillName)
        } else {
            selectedSkillNames.insert(skillName)
        }
    }

    /// Toggle selection state of an Agent
    func toggleAgentSelection(_ agent: AgentType) {
        if selectedAgents.contains(agent) {
            selectedAgents.remove(agent)
        } else {
            selectedAgents.insert(agent)
        }
    }

    /// Reset to initial state (start over)
    func reset() {
        cleanup()
        sourceMode = .remoteClone
        phase = .inputURL
        repoURLInput = ""
        discoveredSkills = []
        selectedSkillNames = []
        selectedAgents = [.claudeCode]
        alreadyInstalledNames = []
        progressMessage = ""
        installedCount = 0
        normalizedRepoURL = ""
        normalizedSource = ""
        lockSourceType = "github"
        targetSkillId = nil
    }

    /// Re-enter selection phase after a local install completes.
    /// Keeps local repository context and refreshes installed badges.
    func backToSelectionForLocalInstall() {
        guard isLocalSource else {
            reset()
            return
        }
        alreadyInstalledNames = Set(skillManager.skills.map(\.id))
        selectedSkillNames = Set(discoveredSkills.map(\.id).filter { !alreadyInstalledNames.contains($0) })
        phase = .selectSkills
    }

    /// Prepare install flow for a custom repository that is already synced locally.
    ///
    /// This skips remote clone/scan and directly enters skill selection.
    func prepareForLocalRepository(
        repoDir: URL,
        repoURL: String,
        repoSource: String,
        discoveredSkills: [GitService.DiscoveredSkill],
        targetSkillId: String?
    ) {
        sourceMode = .localRepository
        lockSourceType = "custom"
        tempRepoDir = repoDir
        ownsTempRepoDir = false
        normalizedRepoURL = repoURL
        normalizedSource = repoSource
        repoURLInput = repoURL
        self.targetSkillId = targetSkillId
        self.discoveredSkills = discoveredSkills

        alreadyInstalledNames = Set(skillManager.skills.map(\.id))
        if let targetSkillId {
            selectedSkillNames = Set(
                discoveredSkills.map(\.id).filter { $0 == targetSkillId && !alreadyInstalledNames.contains($0) }
            )
        } else {
            selectedSkillNames = Set(discoveredSkills.map(\.id).filter { !alreadyInstalledNames.contains($0) })
        }

        phase = .selectSkills
        progressMessage = ""
    }
}

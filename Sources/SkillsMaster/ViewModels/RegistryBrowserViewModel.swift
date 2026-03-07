import Foundation

/// `RegistryBrowserViewModel` 负责 F09 Registry Browser 的页面状态。
///
/// 它主要处理三类场景：
/// 1. **Leaderboard browsing**：展示 all-time / trending / hot 列表
/// 2. **Search**：对 `skills.sh` 执行带 debounce 的搜索
/// 3. **Install**：为选中的 registry skill 触发安装流程
///
/// `@Observable` 会自动追踪属性变化并驱动 SwiftUI 刷新，
/// `@MainActor` 则保证所有 UI state 更新都发生在 main thread。
@MainActor
@Observable
final class RegistryBrowserViewModel {

    // MARK: - State

    /// 当前选中的 leaderboard category tab（All Time / Trending / Hot）。
    var selectedCategory: SkillRegistryService.LeaderboardCategory = .allTime

    /// 用户输入的搜索文本（为空时显示 leaderboard，非空时显示 search result）。
    var searchText = ""

    /// 当前视图中展示的 skills（可能来自 leaderboard，也可能来自 search result）。
    var displayedSkills: [RegistrySkill] = []

    /// 当前是否处于 loading 状态（用于驱动 UI spinner）。
    var isLoading = false

    /// 需要展示的错误信息（`nil` 表示没有错误）。
    var errorMessage: String?

    /// leaderboard scraping 是否失败。
    /// 之所以单独保留这个状态，是为了和 `errorMessage` 区分不同的 UI 呈现方式。
    var leaderboardUnavailable = false

    /// 记录“已安装 skill ID → source repo”的映射，数据来自 `lock file`。
    /// 这样在显示 “Installed” 标记时，就能基于 source 做精确匹配，
    /// 避免两个 `skillId` 相同但 repo 不同的 registry 项被错误合并。
    private var installedSkillSources: [String: String] = [:]

    /// 没有 source 追踪信息的已安装 skill ID 集合（通常表示没有 `lockEntry`）。
    /// 这里保留按 `skillId` 回退匹配的逻辑，用于兼容手动安装、未经过 registry flow 的旧数据。
    private var installedSkillIDsNoSource: Set<String> = []

    /// Install sheet 对应的 `ViewModel`（非 `nil` 时弹出 sheet）。
    ///
    /// 这里采用 `SkillInstallView` 已经建立的 `.sheet(item:)` 绑定模式：
    /// - `installVM != nil` 时展示 sheet
    /// - `installVM == nil` 时关闭 sheet
    /// 这样可以避免 `.sheet(isPresented:)` 常见的双状态同步时序问题。
    var installVM: SkillInstallViewModel?

    // MARK: - Skill Content State

    /// 当前选中 registry skill 的已解析 `SKILL.md` 内容。
    ///
    /// 成功拉取并解析后这里会有值。
    /// 其中同时包含 metadata（如 author、version、license）和 Markdown 正文。
    /// 当用户切换到新的 skill 时，会先重置为 `nil`，再加载新内容。
    var fetchedContent: SkillMDParser.ParseResult?

    /// 当前选中 skill 的 `SKILL.md` 是否正在拉取。
    ///
    /// 这个状态会驱动 detail view 中的 `ProgressView` spinner。
    var isLoadingContent = false

    /// `SKILL.md` 拉取失败时的错误信息（`nil` 表示没有错误）。
    ///
    /// 会显示在 detail view 中，并配合兜底的 “View on skills.sh” 链接一起出现。
    /// 常见原因包括：repo 中不存在 `SKILL.md`、network timeout、内容不是 UTF-8。
    var contentError: String?

    /// 当前选中的 registry skill ID，用于驱动 detail pane。
    ///
    /// 当用户在列表里点击某个 skill 时，这里会被设置为对应的 `id`，
    /// detail pane 随后展示 `RegistrySkillDetailView`。
    var selectedSkillID: String?

    /// 便捷属性：返回当前选中的 `RegistrySkill`。
    ///
    /// 根据 `selectedSkillID` 从 `displayedSkills` 中查找当前选中的 skill。
    /// 如果还没有选中项，或者 ID 无法匹配到任何结果，就返回 `nil`。
    var selectedSkill: RegistrySkill? {
        guard let id = selectedSkillID else { return nil }
        return displayedSkills.first { $0.id == id }
    }

    /// 当前是否处于 search mode。
    /// 这是一个 computed property，不需要单独存储，直接由 `searchText` 推导得出。
    var isSearchActive: Bool {
        !searchText.isEmpty
    }

    // MARK: - Dependencies

    /// 用于 API 调用和 HTML scraping 的 registry service。
    private let registryService = SkillRegistryService()

    /// 用于从 GitHub raw URL 下载 `SKILL.md` 的 content fetcher。
    ///
    /// 它和 `registryService` 一样采用 `actor` 模式维护 thread-safe cache，
    /// 并支持 `main → master` 的 branch fallback。
    private let contentFetcher = SkillContentFetcher()

    /// `SkillManager` 引用，用于判断安装状态并触发安装流程。
    private let skillManager: SkillManager

    // MARK: - Search Debounce

    /// 用于 search-as-you-type 的 debounce task。
    ///
    /// 当用户快速输入时，会取消上一个搜索任务并创建新的任务，
    /// 只有最后一次输入会在 300ms 延迟后真正触发 API 调用。
    /// `Task<Void, Never>` 表示这是一个不返回值、也不会向外抛错的 async task。
    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    /// 通过依赖注入初始化 `SkillManager`。
    ///
    /// `SkillManager` 来自上层 `View` tree（由 `ContentView` 继续向下传递），
    /// `ViewModel` 自己不会新建一份实例。
    init(skillManager: SkillManager) {
        self.skillManager = skillManager
    }

    // MARK: - Lifecycle

    /// 在视图首次出现时调用（由 SwiftUI 的 `.task` 触发）。
    ///
    /// 可以把它理解成“页面首次展示时执行的 async 初始化逻辑”。
    func onAppear() async {
        syncInstalledSkills()
        await loadLeaderboard()
    }

    /// 从 `SkillManager` 同步已安装 skill 数据，用于 source-aware 的 “Installed” 标记。
    ///
    /// 这里会构建两份索引：
    /// - `installedSkillSources`：记录带 `lockEntry` 的 skill 对应 source repo
    /// - `installedSkillIDsNoSource`：记录没有 `lockEntry` 的手动安装 skill
    ///
    /// 这样即使两个 registry skill 拥有相同 `skillId`，只要 source 不同，也不会被同时标记为已安装。
    func syncInstalledSkills() {
        var sources: [String: String] = [:]
        var noSource: Set<String> = []
        for skill in skillManager.skills {
            // 如果 skill 的 `lockEntry` 带有 source（例如 `owner/repo`），
            // 就记录下来，用于后续的精确 source 匹配。
            if let source = skill.lockEntry?.source {
                sources[skill.id] = source
            } else {
                // 没有 `lockEntry` 通常意味着它是手动安装的，不来自 registry。
                // 这里保留按 `skillId` 回退匹配的兼容逻辑。
                noSource.insert(skill.id)
            }
        }
        installedSkillSources = sources
        installedSkillIDsNoSource = noSource
    }

    // MARK: - Leaderboard

    /// Load leaderboard data for the selected category
    ///
    /// Fetches skill data from skills.sh HTML page via SkillRegistryService.
    /// On failure, sets `leaderboardUnavailable` to show a fallback UI suggesting search.
    func loadLeaderboard() async {
        // Don't load leaderboard if user is searching
        guard !isSearchActive else { return }

        isLoading = true
        errorMessage = nil
        leaderboardUnavailable = false

        do {
            let skills = try await registryService.fetchLeaderboard(category: selectedCategory)
            displayedSkills = skills
        } catch {
            // Leaderboard scraping failed — degrade gracefully
            // Don't show a scary error; suggest using search instead
            errorMessage = "Unable to load leaderboard. Try searching instead."
            leaderboardUnavailable = true
            displayedSkills = []
        }

        isLoading = false
    }

    /// Switch leaderboard category tab and reload data
    ///
    /// Called when user clicks a category tab (All Time / Trending / Hot).
    /// The service has a 5-minute cache, so switching between tabs is fast
    /// after the initial load.
    func selectCategory(_ category: SkillRegistryService.LeaderboardCategory) async {
        selectedCategory = category
        await loadLeaderboard()
    }

    /// Refresh current data (clear cache and reload)
    ///
    /// Called from toolbar refresh button. Clears the service cache
    /// so fresh data is fetched from skills.sh.
    func refresh() async {
        await registryService.clearCache()
        if isSearchActive {
            await performSearch()
        } else {
            await loadLeaderboard()
        }
    }

    // MARK: - Search

    /// Called when searchText changes (with debounce)
    ///
    /// Implements search-as-you-type with a 300ms debounce:
    /// 1. Cancel any pending search task
    /// 2. If search text is empty, switch back to leaderboard
    /// 3. Otherwise, wait 300ms then perform search
    ///
    /// The debounce prevents excessive API calls while the user is typing quickly.
    /// `Task.sleep(for:)` suspends the task; if the task is cancelled (by a new keystroke),
    /// the sleep throws CancellationError which is caught by `try?`.
    func onSearchTextChanged() {
        // Cancel previous pending search
        searchTask?.cancel()

        if searchText.isEmpty {
            // User cleared the search field — switch back to leaderboard
            Task { await loadLeaderboard() }
            return
        }

        // Create new debounced search task
        searchTask = Task {
            // Wait 300ms for debounce — if user types another character,
            // this task gets cancelled and a new one starts
            try? await Task.sleep(for: .milliseconds(300))

            // Check if task was cancelled during the sleep (user typed more)
            // Task.isCancelled is a static property on the current task
            guard !Task.isCancelled else { return }

            await performSearch()
        }
    }

    /// Execute search against skills.sh API
    ///
    /// Private method called after debounce completes.
    /// Updates displayedSkills with search results or shows error.
    private func performSearch() async {
        guard !searchText.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let skills = try await registryService.search(query: searchText)
            // Only update if we're still in search mode (user may have cleared search during request)
            if isSearchActive {
                displayedSkills = skills
            }
        } catch {
            if isSearchActive {
                errorMessage = "Search failed: \(error.localizedDescription)"
                displayedSkills = []
            }
        }

        isLoading = false
    }

    // MARK: - Install

    /// Initiate install flow for a registry skill
    ///
    /// Creates a SkillInstallViewModel pre-filled with the skill's source repository,
    /// then sets `autoFetch = true` so the install sheet automatically starts scanning
    /// when it appears (no need for user to click "Scan" manually).
    ///
    /// This reuses the existing F10 install flow (SkillInstallViewModel + SkillInstallView),
    /// which handles: clone repo → scan for SKILL.md → select skills/agents → install.
    ///
    /// - Parameter registrySkill: The registry skill to install
    func installSkill(_ registrySkill: RegistrySkill) {
        let vm = SkillInstallViewModel(skillManager: skillManager)
        // Pre-fill the repo URL input with the skill's source (e.g., "vercel-labs/agent-skills")
        vm.repoURLInput = registrySkill.source
        // Auto-trigger repository scanning when the sheet appears
        vm.autoFetch = true
        // Only pre-select the specific skill the user clicked, not all skills in the repo
        vm.targetSkillId = registrySkill.skillId
        installVM = vm
    }

    /// Check if a registry skill is already installed locally
    ///
    /// Performs source-aware matching to avoid false positives when multiple registry skills
    /// share the same skillId but come from different repositories:
    ///
    /// 1. If a locally installed skill has the same skillId AND a matching source repo
    ///    (from its lock entry), return true — exact match.
    /// 2. If a locally installed skill has the same skillId but NO lock entry (manual install),
    ///    fall back to skillId-only matching for backward compatibility.
    /// 3. Otherwise return false — the skill is not installed.
    func isInstalled(_ registrySkill: RegistrySkill) -> Bool {
        // Check if installed with matching source repo (exact match on both skillId and source)
        if let installedSource = installedSkillSources[registrySkill.skillId] {
            return installedSource == registrySkill.source
        }
        // Fallback: skill installed without source tracking — match by ID only
        return installedSkillIDsNoSource.contains(registrySkill.skillId)
    }

    // MARK: - Skill Content Loading

    /// Load the full SKILL.md content for a registry skill from GitHub
    ///
    /// Called from the detail view's `.task(id:)` modifier — auto-cancels when the user
    /// selects a different skill. This prevents stale content from appearing.
    ///
    /// Flow:
    /// 1. Reset state (clear previous content/error, show loading spinner)
    /// 2. Fetch raw SKILL.md from GitHub via `SkillContentFetcher`
    /// 3. Parse with `SkillMDParser.parse(content:)` to extract metadata + markdown body
    /// 4. Guard against stale updates: only apply if the selected skill hasn't changed
    ///
    /// **Fallback for SKILL.md without frontmatter**: If the content doesn't have YAML frontmatter
    /// (no `---` delimiters), we treat the entire content as the markdown body with empty metadata.
    ///
    /// - Parameter skill: The registry skill whose SKILL.md to fetch
    func loadSkillContent(for skill: RegistrySkill) async {
        // Reset state for new content load
        fetchedContent = nil
        contentError = nil
        isLoadingContent = true

        // Capture the skill ID to guard against stale updates.
        // If the user clicks a different skill while this fetch is in-flight,
        // `selectedSkillID` will change. We check it after the await to discard stale results.
        let targetSkillID = skill.id

        do {
            // Fetch raw SKILL.md content from GitHub
            // SkillContentFetcher tries main branch first, then master, with 10-min cache
            let rawContent = try await contentFetcher.fetchContent(
                source: skill.source,
                skillId: skill.skillId
            )

            // Guard: discard result if user selected a different skill while we were fetching.
            // This is the Swift async equivalent of checking "is this still the current request?"
            // similar to checking a request ID in React's useEffect cleanup.
            guard selectedSkillID == targetSkillID else { return }

            // Parse the SKILL.md content into metadata + markdown body
            do {
                let result = try SkillMDParser.parse(content: rawContent)
                fetchedContent = result
            } catch {
                // Fallback: if parsing fails (e.g., no YAML frontmatter),
                // treat the entire content as the markdown body.
                // Create a minimal metadata with the skill name from the registry.
                let fallbackMetadata = SkillMetadata(
                    name: skill.name,
                    description: ""
                )
                fetchedContent = SkillMDParser.ParseResult(
                    metadata: fallbackMetadata,
                    markdownBody: rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        } catch {
            // Guard: discard error if user selected a different skill
            guard selectedSkillID == targetSkillID else { return }
            contentError = error.localizedDescription
        }

        isLoadingContent = false
    }
}

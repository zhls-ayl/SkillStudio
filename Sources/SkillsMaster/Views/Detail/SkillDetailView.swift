import SwiftUI

/// `SkillDetailView` 是 F03 对应的 skill 详情页。
///
/// 页面会展示完整的 skill 信息，包括：
/// - 基础信息（name、description、author、version）
/// - Agent assignment 状态（可切换）
/// - Markdown 正文
/// - lock file 信息
/// - 操作按钮（edit、delete、open in Finder / Terminal）
struct SkillDetailView: View {

    let skillID: String
    @Bindable var viewModel: SkillDetailViewModel
    @Environment(SkillManager.self) private var skillManager

    /// 编辑时才创建的 `Editor ViewModel`。
    @State private var editorVM: SkillEditorViewModel?

    /// 复制路径按钮的反馈状态：为 `true` 时显示绿色勾选，1.5 秒后自动恢复。
    @State private var pathCopied = false

    var body: some View {
        // 这里相当于 SwiftUI 版的 `guard let`：如果 skill 不存在，就直接展示 empty state。
        if let skill = viewModel.skill(id: skillID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 头部信息区。
                    headerSection(skill)

                    // Package 信息区（含 update 状态），进入详情页后优先展示。
                    // 如果存在 `lockEntry`，展示完整 package 信息；否则展示手动关联 repo 的 UI。
                    Divider()
                    if let lockEntry = skill.lockEntry {
                        lockFileSection(skill, lockEntry)
                    } else {
                        linkToRepoSection(skill)
                    }

                    Divider()

                    // Agent assignment 区域。
                    agentAssignmentSection(skill)

                    Divider()

                    // Markdown 正文区域。
                    markdownSection(skill)
                }
                .padding()
            }
            .navigationTitle(skill.displayName)
            .toolbar {
                ToolbarItemGroup {
                    // 在 Finder 中定位。
                    Button {
                        viewModel.revealInFinder(skill: skill)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Reveal in Finder")

                    // 在 Terminal 中打开。
                    Button {
                        viewModel.openInTerminal(skill: skill)
                    } label: {
                        Image(systemName: "terminal")
                    }
                    .help("Open in Terminal")

                    // 编辑按钮。
                    Button {
                        let vm = SkillEditorViewModel(skillManager: skillManager)
                        vm.load(skill: skill)
                        editorVM = vm
                        viewModel.isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .help("Edit SKILL.md")
                }
            }
            // `sheet` 是 macOS 的 modal dialog。
            .sheet(isPresented: $viewModel.isEditing) {
                if let editorVM {
                    SkillEditorView(
                        viewModel: editorVM,
                        isPresented: $viewModel.isEditing
                    )
                    .frame(minWidth: 700, minHeight: 500)
                }
            }
        } else {
            EmptyStateView(
                icon: "questionmark.circle",
                title: "Skill Not Found",
                subtitle: "The selected skill may have been deleted"
            )
        }
    }

    // MARK: - Sections

    /// 头部信息区。
    @ViewBuilder
    private func headerSection(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(skill.displayName)
                    .font(.title)
                    .fontWeight(.bold)

                ScopeBadge(scope: skill.scope)
            }

            if !skill.metadata.description.isEmpty {
                Text(skill.metadata.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // metadata 行。
            HStack(spacing: 16) {
                if let author = skill.metadata.author {
                    Label(author, systemImage: "person")
                }
                if let version = skill.metadata.version {
                    Label("v\(version)", systemImage: "tag")
                }
                if let license = skill.metadata.license {
                    Label(license, systemImage: "doc.text")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // 路径展示与复制按钮。
            HStack(spacing: 4) {
                Text(skill.canonicalURL.tildeAbbreviatedPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)

                // Copy path button
                // NSPasteboard is macOS clipboard API, equivalent to iOS UIPasteboard
                // .generalPasteboard gets the system general clipboard (source of user's Cmd+V paste)
                Button {
                    let pasteboard = NSPasteboard.general
                    // 调用 `setString` 之前先执行 `clearContents()`，清掉旧内容。
                    pasteboard.clearContents()
                    // 写入完整绝对路径，便于 Terminal 或脚本直接使用。
                    pasteboard.setString(skill.canonicalURL.path, forType: .string)

                    // 设置复制成功状态，图标会暂时切换为绿色勾选。
                    pathCopied = true
                    // `Task.sleep` 是 Swift concurrency 中的非阻塞延迟。
                    // 1.5 秒后自动恢复原始图标。
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        pathCopied = false
                    }
                } label: {
                    // `contentTransition(.symbolEffect(.replace))` 会为 SF Symbol 切换提供系统内置替换动画。
                    // 这里使用 `AnyShapeStyle` 做 type erasure，统一 `.green` 和 `.tertiary` 的类型。
                    Image(systemName: pathCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(pathCopied ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                        .contentTransition(.symbolEffect(.replace))
                }
                // `.plain` button style 会移除默认边框和背景，让按钮看起来更像纯图标。
                .buttonStyle(.plain)
                .help("Copy path to clipboard")
                // `animation` 会监听 `pathCopied` 的变化，并为颜色等属性应用平滑过渡。
                .animation(.easeInOut(duration: 0.2), value: pathCopied)
            }
        }
    }

    /// Agent assignment 区域。 (F06)
    @ViewBuilder
    private func agentAssignmentSection(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent Assignment")
                .font(.headline)

            AgentToggleView(skill: skill, viewModel: viewModel)
        }
    }

    /// Markdown 正文区域。
    @ViewBuilder
    private func markdownSection(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Documentation")
                .font(.headline)

            if skill.markdownBody.isEmpty {
                Text("No documentation available")
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                // `MarkdownContentView` 会异步解析并渲染 Markdown：
                // - `Document(parsing:)` 通过 `.task(id:)` 在后台执行
                // - `LazyVStack` 会延迟渲染屏幕外节点
                // - 解析期间显示轻量的 “Rendering...” 占位文案
                // 这样可以避免大段 Markdown 在主线程触发明显卡顿。
                MarkdownContentView(markdownText: skill.markdownBody)
            }
        }
    }

    /// 手动关联 repository 的区域：仅在 skill 没有 `lockEntry` 时展示。
    ///
    /// 用户可以输入 GitHub repository 地址（`owner/repo` 或完整 URL）。
    /// 关联完成后，SkillsMaster 就能为该 skill 执行更新检查。关联信息只写入私有 cache，不会修改 `lock file`。
    @ViewBuilder
    private func linkToRepoSection(_ skill: Skill) -> some View {
        // 先把 `@Observable` 属性读到本地变量里，避免在深层 `ViewBuilder` 中多次访问时
        // 触发 `AttributeGraph` 的依赖环。
        // 本地变量只会建立一次依赖追踪，可以降低循环依赖出现的概率。
        let isLinking = viewModel.isLinking
        let linkError = viewModel.linkError
        let inputIsEmpty = viewModel.repoURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        VStack(alignment: .leading, spacing: 8) {
            Text("Package Info")
                .font(.headline)

            Text("This skill is not linked to a repository. Link it to enable update checking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 输入区：`TextField` + `Link` 按钮。
            HStack(spacing: 8) {
                // `$viewModel.repoURLInput` 是输入内容的双向绑定。
                // `@Bindable` 让 `@Observable` 对象的属性也能支持 `$` 语法。
                TextField("owner/repo", text: $viewModel.repoURLInput)
                    .textFieldStyle(.roundedBorder)
                    // .onSubmit triggers when user presses return (similar to HTML input's onKeyDown Enter)
                    .onSubmit {
                        Task { await viewModel.linkToRepository(skill: skill) }
                    }
                    .disabled(isLinking)

                if isLinking {
                    // Linking: show ProgressView (spinning indicator)
                    ProgressView()
                        .controlSize(.small)
                    Text("Linking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Link") {
                        Task { await viewModel.linkToRepository(skill: skill) }
                    }
                    .disabled(inputIsEmpty)
                }
            }

            // Error message
            if let error = linkError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Lock file info section
    @ViewBuilder
    private func lockFileSection(_ skill: Skill, _ lockEntry: LockEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行：Package Info + 更新检查按钮
            HStack {
                Text("Package Info")
                    .font(.headline)

                Spacer()

                // F12: 更新状态指示和操作按钮
                updateStatusView(skill)
            }

            // Grid is macOS 14+ grid layout (similar to HTML CSS Grid)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Source").foregroundStyle(.secondary)
                    Text(lockEntry.source).textSelection(.enabled)
                }
                GridRow {
                    Text("Repository").foregroundStyle(.secondary)
                    // If sourceUrl is valid URL, show as clickable link, opens in system default browser when clicked
                    if let url = URL(string: lockEntry.sourceUrl),
                       url.scheme != nil {
                        Link(lockEntry.sourceUrl, destination: url)
                            .textSelection(.enabled)
                    } else {
                        Text(lockEntry.sourceUrl).textSelection(.enabled)
                    }
                }
                // Prefer displaying commit hash (can be viewed directly on GitHub),
                // fallback to tree hash if not present (old skill not backfilled)
                GridRow {
                    if let commitHash = skill.localCommitHash {
                        Text("Commit").foregroundStyle(.secondary)
                        Text(commitHash)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Text("Tree Hash").foregroundStyle(.secondary)
                        Text(lockEntry.skillFolderHash)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                GridRow {
                    Text("Installed").foregroundStyle(.secondary)
                    Text(lockEntry.installedAt.formattedDate)
                }
                GridRow {
                    Text("Updated").foregroundStyle(.secondary)
                    Text(lockEntry.updatedAt.formattedDate)
                }
            }
            .font(.subheadline)
        }
    }

    /// F12: Update status indicator view
    ///
    /// Displays different UI based on viewModel's update check status:
    /// - Checking: ProgressView + "Checking..."
    /// - Has update: orange label + "Update" button
    /// - Updating: ProgressView + "Updating..."
    /// - Up to date: green checkmark (auto-disappears after 2 seconds)
    /// - Default: check button
    @ViewBuilder
    private func updateStatusView(_ skill: Skill) -> some View {
        if viewModel.isCheckingUpdate {
            // Checking for updates
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.isUpdating {
            // Performing update
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Updating...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if skill.hasUpdate {
            // Has available update: show hash comparison + GitHub link + Update button
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Label("Update Available", systemImage: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Button("Update") {
                        Task { await viewModel.updateSkill(skill) }
                    }
                    .controlSize(.small)
                }

                // Commit hash comparison row + GitHub link
                // Displays localHash → remoteHash (7-character short format, consistent with git log --oneline)
                updateDetailRow(skill)
            }
        } else if viewModel.showUpToDate {
            // Already up to date (auto-disappears after 2 seconds)
            Label("Up to Date", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else if let error = viewModel.updateError {
            // 更新检查出错
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            // Default state: show check button
            Button {
                Task { await viewModel.checkForUpdate(skill: skill) }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .controlSize(.small)
            .help("Check for updates")
        }
    }

    /// F12: Update detail row — displays commit hash comparison and GitHub link
    ///
    /// Layout: `abc1234 → def5678   View changes on GitHub ↗`
    /// - Hash comparison: local commit hash → remote commit hash (7-character short format, consistent with git log --oneline)
    /// - GitHub link: opens compare page in browser when clicked
    @ViewBuilder
    private func updateDetailRow(_ skill: Skill) -> some View {
        HStack(spacing: 6) {
            // Take first 7 characters short format (consistent with git log --oneline)
            // prefix(_:) returns Substring, needs to be wrapped in String()
            let localShort = skill.localCommitHash.map { String($0.prefix(7)) }
            let remoteShort = skill.remoteCommitHash.map { String($0.prefix(7)) }

            if let localShort, let remoteShort {
                // Have both commit hashes: show comparison `abc1234 → def5678`
                Text("\(localShort) → \(remoteShort)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else if let remoteShort {
                // Only have remote commit hash (fallback when old skill backfill failed)
                Text("→ \(remoteShort)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // GitHub compare link button
            if let url = githubCompareURL(skill) {
                // Use link-style text button, opens in browser when clicked
                // NSWorkspace.shared.open() is the standard way to open URLs on macOS
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 2) {
                        Text("View changes on GitHub")
                        // arrow.up.right is external link icon (↗), indicates will jump to browser
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: - Helper Methods

    /// Generate GitHub compare URL
    ///
    /// Generates GitHub comparison page URL based on lockEntry.sourceUrl and commit hash:
    /// - Have both commit hashes: `https://github.com/owner/repo/compare/<local>...<remote>`
    ///   GitHub compare view shows all file differences between two commits
    /// - Only have remote commit hash: `https://github.com/owner/repo/commit/<remote>`
    ///   Shows detail page for the remote latest commit
    private func githubCompareURL(_ skill: Skill) -> URL? {
        guard let sourceUrl = skill.lockEntry?.sourceUrl,
              let baseURL = GitService.githubWebURL(from: sourceUrl),
              let remoteHash = skill.remoteCommitHash else {
            return nil
        }

        // If have local commit hash, generate compare URL to show differences between two commits
        // GitHub compare URL format: compare/<base>...<head>
        // Where `...` indicates three-dot diff (shows changes in head relative to base)
        if let localHash = skill.localCommitHash {
            return URL(string: "\(baseURL)/compare/\(localHash)...\(remoteHash)")
        }

        // No local commit hash (backfill not successful), only link to remote commit page
        return URL(string: "\(baseURL)/commit/\(remoteHash)")
    }
}

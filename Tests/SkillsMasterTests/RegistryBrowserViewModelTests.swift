import XCTest
@testable import SkillsMaster

/// `RegistryBrowserViewModel` 的单元测试。
///
/// 这些测试主要覆盖 source-aware 的 “Installed” 标记逻辑，
/// 用来防止不同 repository 中同名 `skillId` 被错误地同时标记为已安装。
///
/// 由于 `RegistryBrowserViewModel` 和 `SkillManager` 都是 `@MainActor` 隔离对象，
/// 因此测试类也需要运行在 `@MainActor` 上。
@MainActor
final class RegistryBrowserViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// 创建一个最小可用的 `Skill` model，用于测试。
    private func makeSkill(id: String, source: String? = nil) -> Skill {
        // 只有传入 `source` 时才构造 `LockEntry`；否则表示手动安装的 skill。
        let lockEntry: LockEntry? = source.map { src in
            LockEntry(
                source: src,
                sourceType: "github",
                sourceUrl: "https://github.com/\(src).git",
                skillPath: "skills/\(id)/SKILL.md",
                skillFolderHash: "abc123",
                installedAt: "2025-01-01T00:00:00Z",
                updatedAt: "2025-01-01T00:00:00Z"
            )
        }

        return Skill(
            id: id,
            canonicalURL: URL(fileURLWithPath: "/tmp/skills/\(id)"),
            metadata: SkillMetadata(name: id, description: ""),
            markdownBody: "",
            scope: .unassigned,
            installations: [],
            lockEntry: lockEntry
        )
    }

    /// 创建一个最小可用的 `RegistrySkill`，用于 registry 场景测试。
    private func makeRegistrySkill(skillId: String, source: String) -> RegistrySkill {
        RegistrySkill(
            id: "\(source)/\(skillId)",
            skillId: skillId,
            name: skillId,
            installs: 100,
            source: source,
            installsYesterday: nil,
            change: nil
        )
    }

    // MARK: - isInstalled Tests

    /// 验证：当 `skillId` 与 `source` 都匹配时，`isInstalled` 返回 `true`。
    func testIsInstalledReturnsTrueWhenSourceMatches() {
        let skillManager = SkillManager()
        // Simulate a locally installed skill with a lock entry recording its source repo
        skillManager.skills = [makeSkill(id: "ui-ux-pro-max", source: "alice/skills")]

        let vm = RegistryBrowserViewModel(skillManager: skillManager)
        vm.syncInstalledSkills()

        // Registry skill from the SAME repo should be marked as installed
        let registrySkill = makeRegistrySkill(skillId: "ui-ux-pro-max", source: "alice/skills")
        XCTAssertTrue(vm.isInstalled(registrySkill), "Should be installed when skillId and source both match")
    }

    /// 验证：当 `skillId` 相同但 `source` 不同时，`isInstalled` 返回 `false`。
    func testIsInstalledReturnsFalseWhenSourceDiffers() {
        let skillManager = SkillManager()
        // Locally installed from "alice/skills"
        skillManager.skills = [makeSkill(id: "ui-ux-pro-max", source: "alice/skills")]

        let vm = RegistryBrowserViewModel(skillManager: skillManager)
        vm.syncInstalledSkills()

        // Registry skill from a DIFFERENT repo should NOT be marked as installed
        let registrySkill = makeRegistrySkill(skillId: "ui-ux-pro-max", source: "bob/other-skills")
        XCTAssertFalse(vm.isInstalled(registrySkill), "Should NOT be installed when source differs even if skillId matches")
    }

    /// 验证：对于没有 `lockEntry` 的手动安装 skill，`isInstalled` 会回退到仅按 `skillId` 匹配。
    func testIsInstalledFallbackForSkillWithoutLockEntry() {
        let skillManager = SkillManager()
        // Manually installed skill — no lock entry, so no source info
        skillManager.skills = [makeSkill(id: "my-custom-skill")]

        let vm = RegistryBrowserViewModel(skillManager: skillManager)
        vm.syncInstalledSkills()

        // Any registry skill with matching skillId should be marked as installed (fallback behavior)
        let registrySkill = makeRegistrySkill(skillId: "my-custom-skill", source: "anyone/any-repo")
        XCTAssertTrue(vm.isInstalled(registrySkill), "Should be installed via ID-only fallback when no lock entry exists")
    }

    /// 验证：对完全未安装的 skill，`isInstalled` 应返回 `false`。
    func testIsInstalledReturnsFalseForUninstalledSkill() {
        let skillManager = SkillManager()
        // Install a different skill
        skillManager.skills = [makeSkill(id: "some-other-skill", source: "alice/skills")]

        let vm = RegistryBrowserViewModel(skillManager: skillManager)
        vm.syncInstalledSkills()

        // Registry skill with a completely different skillId should not be installed
        let registrySkill = makeRegistrySkill(skillId: "ui-ux-pro-max", source: "alice/skills")
        XCTAssertFalse(vm.isInstalled(registrySkill), "Should NOT be installed when skillId doesn't match any local skill")
    }
}

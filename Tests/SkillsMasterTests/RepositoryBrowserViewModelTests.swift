import XCTest
@testable import SkillsMaster

@MainActor
final class RepositoryBrowserViewModelTests: XCTestCase {

    func testApplyScanResultShowsDirtyWorkingTreeNotice() async {
        let skillManager = SkillManager()
        let repository = makeRepository()
        let vm = RepositoryBrowserViewModel(repository: repository, skillManager: skillManager)

        let scanResult = RepositoryManager.ScanResult(
            skills: [makeDiscoveredSkill(id: "dirty-skill")],
            cacheStatus: .bypassedDirtyWorkingTree
        )

        await vm.applyScanResult(scanResult)

        XCTAssertEqual(vm.allSkills.count, 1)
        XCTAssertEqual(
            vm.scanNoticeMessage,
            RepositoryManager.ScanCacheStatus.bypassedDirtyWorkingTree.noticeMessage
        )
    }

    func testApplyScanResultClearsDirtyWorkingTreeNoticeAfterNormalScan() async {
        let skillManager = SkillManager()
        let repository = makeRepository()
        let vm = RepositoryBrowserViewModel(repository: repository, skillManager: skillManager)

        await vm.applyScanResult(.init(
            skills: [makeDiscoveredSkill(id: "dirty-skill")],
            cacheStatus: .bypassedDirtyWorkingTree
        ))
        await vm.applyScanResult(.init(
            skills: [makeDiscoveredSkill(id: "clean-skill")],
            cacheStatus: .miss
        ))

        XCTAssertEqual(vm.allSkills.map(\.id), ["clean-skill"])
        XCTAssertNil(vm.scanNoticeMessage)
    }

    private func makeRepository() -> SkillRepository {
        SkillRepository(
            id: UUID(),
            name: "team-skills",
            repoURL: "https://example.com/org/repo.git",
            authType: .httpsToken,
            platform: .github,
            isEnabled: true,
            lastSyncedAt: nil,
            localSlug: "org-repo",
            httpUsername: nil,
            credentialKey: nil,
            scanHiddenPaths: false,
            syncOnLaunch: false
        )
    }

    private func makeDiscoveredSkill(id: String) -> GitService.DiscoveredSkill {
        GitService.DiscoveredSkill(
            id: id,
            folderPath: "skills/\(id)",
            skillMDPath: "skills/\(id)/SKILL.md",
            metadata: SkillMetadata(name: id, description: ""),
            markdownBody: ""
        )
    }
}

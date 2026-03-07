import XCTest
@testable import SkillsMaster

/// SymlinkManager 的单元测试
///
/// 测试策略：在临时目录中创建模拟的 skill 目录和 symbolic link
/// 注意：这些测试需要文件系统权限
final class SymlinkManagerTests: XCTestCase {

    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillsMasterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    // MARK: - isSymlink Tests

    /// 测试检测 symbolic link
    func testIsSymlink() throws {
        let fm = FileManager.default

        // 创建源目录
        let sourceDir = tempDir.appendingPathComponent("source")
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        // 创建 symbolic link
        let linkPath = tempDir.appendingPathComponent("link")
        try fm.createSymbolicLink(at: linkPath, withDestinationURL: sourceDir)

        // 验证
        XCTAssertTrue(SymlinkManager.isSymlink(at: linkPath))
        XCTAssertFalse(SymlinkManager.isSymlink(at: sourceDir))
    }

    /// 测试检测不存在的路径
    func testIsSymlinkNonExistent() {
        let nonExistent = tempDir.appendingPathComponent("does-not-exist")
        XCTAssertFalse(SymlinkManager.isSymlink(at: nonExistent))
    }

    // MARK: - resolveSymlink Tests

    /// 测试解析 symbolic link
    func testResolveSymlink() throws {
        let fm = FileManager.default

        let sourceDir = tempDir.appendingPathComponent("real-skill")
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let linkPath = tempDir.appendingPathComponent("linked-skill")
        try fm.createSymbolicLink(at: linkPath, withDestinationURL: sourceDir)

        let resolved = SymlinkManager.resolveSymlink(at: linkPath)
        XCTAssertEqual(resolved.standardized.path, sourceDir.standardized.path)
    }

    /// 测试解析非 symbolic link 路径（应该返回原路径）
    func testResolveNonSymlink() throws {
        let dir = tempDir.appendingPathComponent("normal-dir")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let resolved = SymlinkManager.resolveSymlink(at: dir)
        XCTAssertEqual(resolved.path, dir.path)
    }
}

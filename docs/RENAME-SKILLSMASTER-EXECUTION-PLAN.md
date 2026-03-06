# SkillStudio → SkillsMaster 重命名执行方案（子 Agent 拆分版）

## 1. 目标与边界

### 目标
- 将项目名称从 `SkillStudio` 统一重命名为 `SkillsMaster`。
- 保证工程可构建、可测试、可打包、可发布。

### 明确边界（按你的要求）
- 将缓存路径迁移逻辑改为：`~/.agents -> ~/.skillsmaster`。
- **不考虑** `~/.skillstudio -> ~/.skillsmaster` 数据迁移。
- 当前处于开发阶段，**不做历史兼容**（不保留旧命名双轨、不保留旧更新 fallback）。

### 非目标
- 不处理旧版本平滑升级兼容。
- 不处理旧 Homebrew cask 迁移指引（可后续单独加）。

---

## 2. 总体策略

采用“一次切换、分组提交、并行执行”的方式：

1. 先改工程与代码标识（会影响编译）。
2. 再改脚本与 CI/Release（会影响产物发布）。
3. 最后改文档与分发说明（会影响对外展示）。
4. 末尾做全量回归：`build + test + package + grep 清扫`。

这样可以把失败定位缩小到某一组改动，便于快速回滚。

---

## 3. 子 Agent 划分（建议 4 个）

## Agent A：Core Rename（核心工程重命名）

### 负责范围
- `Package.swift`
- `Sources/SkillStudio` 目录重命名为 `Sources/SkillsMaster`
- `Tests/SkillStudioTests` 目录重命名为 `Tests/SkillsMasterTests`
- 全量替换 `@testable import SkillStudio -> @testable import SkillsMaster`
- 入口类型名、UI 导航标题、设置页品牌名等代码内展示文本

### 关键约束
- **必须**将 `Constants.sharedSkillsPath` 等 canonical 路径切换到 `~/.skillsmaster`。
- **必须**将 `MigrationManager` 迁移方向切换为 `~/.agents -> ~/.skillsmaster`。
- **不得**新增 `~/.skillstudio -> ~/.skillsmaster` 的二次迁移分支。

### 产出物
- 编译通过的核心代码重命名提交。

### 验收命令
```bash
swift build
swift test
```

### Definition of Done
- `swift build` 成功。
- `swift test` 成功。
- `rg -n "@testable import SkillStudio" Tests` 无结果。

---

## Agent B：Release & Packaging（构建/发布链路重命名）

### 负责范围
- `scripts/package-app.sh`
- `scripts/run.sh`
- `.github/workflows/release.yml`
- `.github/workflows/ci.yml`（若有名称相关展示）
- `homebrew/skillstudio.rb`（重命名为 `homebrew/skillsmaster.rb` 并更新内容）

### 关键任务
- 应用名改为 `SkillsMaster`（`.app`、可执行文件、zip 名一致）。
- Bundle ID 统一为新命名（建议 `com.github.skillsmaster`）。
- Release workflow 产物路径、校验、上传文件名全部对齐新命名。
- Homebrew cask 名称与下载 URL 对齐新仓库/新产物名。

### 产出物
- 可生成 `SkillsMaster.app` 与 zip 包的脚本/工作流提交。

### 验收命令
```bash
./scripts/package-app.sh --version 0.0.0-dev
file build/SkillsMaster.app/Contents/MacOS/SkillsMaster
```

### Definition of Done
- 打包成功，且产物路径、二进制文件名、Info.plist 名称一致。
- release workflow 中不再引用 `SkillStudio.app`。

---

## Agent C：Update & Runtime Naming（运行时命名与更新链路）

### 负责范围
- `Sources/SkillsMaster/Services/UpdateChecker.swift`（目录重命名后路径）
- 代码内临时目录名、脚本名、User-Agent、GitHub 仓库 URL、默认下载文件名
- 任何运行时显示 `SkillStudio` 的字符串（仅命名与运行时标识，不新增二次迁移逻辑）

### 关键任务
- 更新接口地址改为新仓库（`.../SkillsMaster/releases/latest`）。
- 下载 URL 模板改为 `SkillsMaster-vX.Y.Z-universal.zip`。
- 临时目录/脚本名改为 `SkillsMasterUpdate`、`skillsmaster_update.sh`。

### 关键约束
- 不增加旧仓库 fallback（按“无需历史兼容”）。
- 不触碰 `MigrationManager` 之外的迁移策略扩展（禁止新增 `~/.skillstudio -> ~/.skillsmaster`）。

### 验收命令
```bash
swift build
rg -n "SkillStudio|skillstudio" Sources/SkillsMaster/Services/UpdateChecker.swift
```

### Definition of Done
- UpdateChecker 仅保留必要历史注释（如无必要应清零）。
- 构建通过。

---

## Agent D：Docs & Communication（文档与对外信息）

### 负责范围
- `README.md`（优先）
- `docs/*.md`
- `CLAUDE.md` 中命令示例与路径描述
- 徽章、仓库链接、Release 下载链接、brew 安装命令

### 关键任务
- 文案名称统一改为 `SkillsMaster`。
- 安装命令与下载文件名统一改为新命名。
- 开发指南中的目录树、命令示例、app 名称全部更新。

### 验收命令
```bash
rg -n "SkillStudio|skillstudio" README.md docs CLAUDE.md
```

### Definition of Done
- README 与 docs 不再出现旧产品名（除明确“历史背景”段落）。
- 所有命令可直接复制执行，不引用旧产物名。

---

## 4. 并行执行顺序（依赖图）

1. 先启动 Agent A（核心工程重命名，决定新目录结构）。
2. Agent A 完成后，Agent B 与 Agent C 可并行。
3. Agent D 可并行，但需在 A 完成后再做最终校对（避免路径变更导致文档失效）。
4. 最后由集成负责人执行统一回归验证。

---

## 5. 集成负责人（你或主 Agent）最终检查清单

## 必跑命令
```bash
swift build
swift test
./scripts/package-app.sh --version 0.0.0-dev
./scripts/run.sh
rg -n "SkillStudio|skillstudio" -S .
```

## 必查项
- `Package.swift` 的 package/target/testTarget 名称是否全部改为 `SkillsMaster`。
- 应用产物是否为 `build/SkillsMaster.app`。
- 可执行文件是否为 `SkillsMaster`。
- release workflow 上传文件名是否为 `SkillsMaster-v*.zip`。
- 已完成迁移方向切换为 `~/.agents -> ~/.skillsmaster`，且未新增 `~/.skillstudio -> ~/.skillsmaster` 迁移逻辑。

---

## 6. 提交分批建议（避免巨型提交）

1. `refactor(core): rename SPM targets and source/test directories to SkillsMaster`
2. `build(release): rename app artifact and workflows to SkillsMaster`
3. `refactor(update): rename update checker endpoints and runtime labels`
4. `docs: rename product references from SkillStudio to SkillsMaster`
5. `chore: final grep cleanup for legacy naming`

---

## 7. 可直接下发给子 Agent 的任务模板

## 模板 A（Core）
> 在当前分支执行：将 SwiftPM 包/target 与源码测试目录从 SkillStudio 重命名为 SkillsMaster；修复编译和测试导入；并将 canonical 路径与迁移方向统一改为 `~/.agents -> ~/.skillsmaster`。禁止新增 `~/.skillstudio -> ~/.skillsmaster` 二次迁移逻辑。完成后执行 `swift build && swift test` 并提交变更清单。

## 模板 B（Release）
> 在当前分支执行：将打包脚本、release workflow、homebrew cask 从 SkillStudio 命名切换为 SkillsMaster，确保产物为 `SkillsMaster.app` 与 `SkillsMaster-vX.Y.Z-universal.zip`。完成后执行打包命令并汇报产物路径。

## 模板 C（Update）
> 在当前分支执行：将 UpdateChecker 中仓库 URL、下载模板、临时目录名和脚本名改为 SkillsMaster，不保留旧命名 fallback；不新增 `~/.skillstudio -> ~/.skillsmaster` 迁移。完成后执行 `swift build` 并汇报关键 diff。

## 模板 D（Docs）
> 在当前分支执行：更新 README 与 docs 的品牌名、仓库链接、release 文件名和 brew 命令为 SkillsMaster；保留技术语义不变。完成后执行 `rg -n "SkillStudio|skillstudio" README.md docs CLAUDE.md` 并解释剩余项。

# SkillsMaster

SkillsMaster 是一个面向 macOS 的原生应用，用统一的图形界面管理多种 AI 编程代理的 Skills。它聚焦于 **扫描、展示、安装、编辑、更新、同步**，把本地目录、symbolic link、lock file 与 Repository 来源整合成一套可维护的工作流。

![SkillsMaster 界面截图](docs/screenshots/skill-detail.png)

## 它解决什么问题
如果你同时使用多个 AI 编程代理，通常会遇到这些问题：
- Skills 分散在不同目录，难以统一查看
- `SKILL.md` 需要手动编辑，容易出错
- symbolic link、lock file、仓库来源难以追踪
- 想检查更新或切换 Agent 安装状态时，缺少统一入口

SkillsMaster 的目标，就是把这些分散的本地操作整合到一个清晰的 macOS UI 里完成。

## 核心能力
- 统一扫描本地 Skills，并按 Agent、作用域、安装状态集中展示
- 解析并编辑 `SKILL.md`，支持 YAML frontmatter + Markdown 正文
- 从 GitHub、Registry 与 Custom Repository 安装 Skills
- 管理 Agent 分配、symbolic link、lock file 与更新检查
- 监听文件系统变化，在 UI 中自动刷新
- 支持主题切换、应用版本检查与 Release 打包链路

## 适用人群
- 同时使用 Claude Code、Codex、Gemini CLI、GitHub Copilot、Cursor、OpenCode 等多个 Agent 的开发者
- 希望通过 GUI 管理本地 Skills，而不是频繁手改目录和配置文件的用户
- 需要追踪 Skill 来源、更新状态与安装归属的维护者

## 环境要求
- macOS 14+
- Xcode 15+
- Swift 5.9+

## 快速开始
### 从源码运行
```bash
git clone <your-repo-url>
cd SkillsMaster
./run
```

### 运行测试
```bash
swift test
```

### 打包应用
```bash
./scripts/package-app.sh --version 1.2.3 --zip
```

## 仓库结构
- `Sources/SkillsMaster/`：应用源码
- `Tests/SkillsMasterTests/`：单元测试
- `scripts/`：运行、打包、Release 相关脚本
- `docs/`：架构、开发、发布与能力边界文档
- `.github/workflows/`：CI / Release workflow

## 文档入口
- `docs/README.md`：文档总览
- `docs/architecture.md`：架构、路径、数据流与高风险区域
- `docs/development.md`：开发工作流、测试与文档更新要求
- `docs/release.md`：打包、发布、GitHub Actions、Homebrew
- `docs/roadmap.md`：当前能力边界与未实现项

## 开发约束
- 文档必须反映当前实现，不能把过时设计继续当成事实
- 修改代码后优先补测试；修改行为后同步补文档
- 涉及路径迁移、仓库同步、lock file、Release 脚本时，按高风险改动处理

如果你准备参与开发，建议先阅读 `AGENTS.md` 与 `docs/README.md`。

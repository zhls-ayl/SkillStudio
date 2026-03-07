# SkillsMaster

SkillsMaster 是一个 macOS 原生应用，用统一的图形界面管理多种 AI 编程代理的 Skills。它聚焦于 **扫描、展示、安装、编辑、更新、同步**，并把多代理目录、symbolic link、lock file 与仓库来源收敛到一套可维护的工程实现中。

![SkillsMaster 界面截图](docs/screenshots/skill-detail.png)

## 当前能力概览
- 扫描本地 Skills，并按代理、作用域、安装状态统一展示
- 解析与编辑 `SKILL.md`（YAML frontmatter + Markdown 正文）
- 从远程仓库、注册表或自定义仓库安装 Skills
- 管理代理分配、symbolic link、lock file 与更新检查
- 监控文件系统变更，并在 UI 中自动刷新
- 支持应用主题切换、自身版本检查与 Release 打包链路

## 环境要求
- macOS 14+
- Xcode 15+
- Swift 5.9+

## 常用命令
```bash
swift build
swift test
./run
./scripts/package-app.sh --version 1.2.3 --zip
```

## 代码结构概览
- `Sources/SkillsMaster/`：应用源码
- `Tests/SkillsMasterTests/`：单元测试
- `scripts/`：打包、Release 与图标相关脚本
- `docs/`：工程文档
- `.github/workflows/`：CI / Release workflow

## 文档导航入口
- `docs/README.md`：文档总览
- `docs/architecture.md`：架构、路径、数据流与风险点
- `docs/development.md`：开发工作流、测试与文档更新要求
- `docs/release.md`：打包、发布、GitHub Actions、Homebrew
- `docs/roadmap.md`：当前能力边界与后续方向

## 开发原则与约束
- 文档必须反映当前实现，不能把过时设计继续当成事实。
- 修改代码后优先补测试；修改行为后同步补文档。
- 涉及路径迁移、仓库同步、lock file、Release 脚本时，按高风险改动处理。

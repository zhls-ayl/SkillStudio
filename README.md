<p align="center">
  <img src="Assets/AppIcon2.svg" width="200" alt="SkillStudio App Icon" />
</p>

<h1 align="center">SkillStudio</h1>

<p align="center">
  <em>可视化管理 AI 编程代理 Skills 的原生 macOS 应用</em>
</p>

<p align="center">
  <a href="https://github.com/zhls-ayl/SkillStudio/actions/workflows/ci.yml"><img src="https://github.com/zhls-ayl/SkillStudio/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="https://github.com/zhls-ayl/SkillStudio/releases/latest"><img src="https://img.shields.io/github/v/release/zhls-ayl/SkillStudio?include_prereleases" alt="Release" /></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange" alt="Swift" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
</p>

---

## 项目说明

**SkillStudio** 是一款 macOS 原生桌面应用，提供统一的 GUI 界面来管理多个 AI 编程代理的 Skills。无需手动编辑文件、管理符号链接或解析 YAML。

本项目基于 [SkillDeck](https://github.com/crossoverJie/SkillDeck) 重构维护，感谢原作者 [crossoverJie](https://github.com/crossoverJie) 的优秀工作。

## 功能特性

- **多代理支持** — Claude Code、Codex、Gemini CLI、Copilot CLI、OpenCode、Antigravity、Cursor、Kiro、CodeBuddy、OpenClaw、Trae
- **注册表浏览** — 浏览 [skills.sh](https://skills.sh) 排行榜（全部 / 趋势 / 热门），搜索并一键安装
- **统一仪表板** — 三栏式原生 macOS 视图，一览所有已安装技能
- **主题切换** — 在设置页可选 System / Light / Dark，全局窗口统一生效并自动持久化
- **一键安装** — 从 GitHub 克隆，自动创建符号链接并更新锁文件
- **更新检查** — 检测远程变更，一键拉取更新
- **SKILL.md 编辑器** — 分栏式编辑器，表单 + Markdown 实时预览
- **代理分配** — 通过开关切换技能的代理安装状态，自动管理符号链接
- **文件系统监控** — 自动感知 CLI 端变更，即时同步

> 完整功能列表与路线图请参阅 [docs/FEATURES.md](docs/FEATURES.md)

## 安装

### Homebrew（推荐）

```bash
brew tap zhls-ayl/skillstudio && brew install --cask skillstudio
```

### 下载 Release

从 [GitHub Releases](https://github.com/zhls-ayl/SkillStudio/releases) 下载最新通用二进制：

1. 下载 `SkillStudio-vX.Y.Z-universal.zip`
2. 解压后将 `SkillStudio.app` 移至 `/Applications/`
3. 首次启动时需要解除 macOS 安全限制：
   ```bash
   xattr -cr /Applications/SkillStudio.app
   ```
   或右键点击应用 → 打开 → 在弹窗中点击"打开"

### 从源码构建

需要 macOS 14.0+ (Sonoma)、Xcode 15.0+、Swift 5.9+。

```bash
git clone https://github.com/zhls-ayl/SkillStudio.git
cd SkillStudio
./run    # 自动处理目录迁移后常见的 Swift 缓存问题

# 或在 Xcode 中打开
open Package.swift    # 按 Cmd+R 运行
```

运行测试：

```bash
swift test
```

## 支持的代理

| 代理 | Skills 目录 | 检测方式 | Skills 读取优先级 |
|------|------------|---------|------------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `~/.claude/skills/` | `claude` 二进制 + 配置目录 | 仅自有目录 |
| [Codex](https://github.com/openai/codex) | `~/.codex/skills/` | `codex` 二进制 | 自有 → `~/.agents/skills/` |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `~/.gemini/skills/` | `gemini` 二进制 + 配置目录 | 仅自有目录 |
| [Copilot CLI](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line) | `~/.copilot/skills/` | `gh` 二进制 | 自有 → `~/.claude/skills/` |
| [OpenCode](https://opencode.ai) | `~/.config/opencode/skills/` | `opencode` 二进制 | 自有 → `~/.claude/skills/` → `~/.agents/skills/` |
| [Antigravity](https://antigravity.google) | `~/.gemini/antigravity/skills/` | `antigravity` 二进制 | 仅自有目录 |
| [Cursor](https://cursor.com) | `~/.cursor/skills/` | `cursor` 二进制 | 自有 → `~/.claude/skills/` |
| [Kiro](https://kiro.dev) | `~/.kiro/skills/` | `kiro` 二进制 | 仅自有目录 |
| [CodeBuddy](https://www.codebuddy.ai) | `~/.codebuddy/skills/` | `codebuddy` 二进制 | 仅自有目录 |
| [OpenClaw](https://openclaw.ai) | `~/.openclaw/skills/` | `openclaw` 二进制 | 仅自有目录 |
| [Trae](https://trae.ai) | `~/.trae/skills/` | `trae` 二进制 | 仅自有目录 |

## 架构

采用 MVVM + `@Observable`（macOS 14+）架构。文件系统即数据库 — Skills 是包含 `SKILL.md` 文件的目录。Services 使用 Swift `actor` 确保线程安全的文件系统访问。

```
Views → ViewModels (@Observable) → SkillManager → Services (actor)
```

> 完整架构指南与开发设置请参阅 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)

## 贡献指南

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feat/my-feature`)
3. 运行测试 (`swift test`)
4. 提交 Pull Request

> 详细的开发环境搭建与编码规范请参阅 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)

## 许可证

[MIT](LICENSE)

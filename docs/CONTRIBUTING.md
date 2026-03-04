# 贡献指南

感谢你对 SkillStudio 的关注！欢迎通过以下方式参与贡献。

## 开始之前

1. 确保你的开发环境满足要求：
   - macOS 14.0+ (Sonoma)
   - Xcode 15.0+
   - Swift 5.9+

2. 阅读 [DEVELOPMENT.md](DEVELOPMENT.md) 了解项目架构和编码规范。

## 贡献流程

1. **Fork** 本仓库
2. **创建功能分支**
   ```bash
   git checkout -b feat/my-feature
   ```
3. **编写代码** — 遵循项目已有的代码风格和架构模式
4. **编写测试** — 为新功能添加对应的单元测试
5. **运行测试**
   ```bash
   swift test
   ```
6. **提交变更** — 使用清晰的提交信息
7. **推送并创建 Pull Request**

## 代码规范

- 遵循 Swift 官方编码风格
- 使用 `@Observable` 而非 `ObservableObject`
- Services 层使用 `actor` 确保线程安全
- UI 视图保持轻量，业务逻辑放在 ViewModel 中

## 报告问题

如果你发现了 Bug 或有功能建议，请通过 [GitHub Issues](https://github.com/zhls-ayl/SkillStudio/issues) 提交。

提交 Bug 报告时请包含：
- macOS 版本
- 复现步骤
- 预期行为与实际行为
- 相关日志或截图

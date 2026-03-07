# 开发工作流

## 本地环境
- macOS 14+
- Xcode 15+
- Swift 5.9+

推荐优先使用：
- `./run`：本地运行，自动处理仓库路径迁移后常见的 Swift 模块缓存问题
- `swift test`：执行全部单元测试
- `swift test --filter <TestCase>`：执行最小相关测试

## 常用命令
```bash
swift build
swift build -c release
swift test
swift test --filter SkillMDParserTests
swift test --enable-code-coverage
swift package clean
./run
```

## 开发流程
1. 先确认需求、范围、风险点与交付物
2. 阅读相关 `Service` / `ViewModel` / `View` / `Tests`
3. 判断是否涉及路径、迁移、lock file、仓库同步、Release 脚本等高风险区域
4. 做最小可验证变更（minimal change）
5. 补充或更新相邻测试用例
6. 更新对应文档
7. 最后检查 README、docs 与代码命名是否一致

## 代码约束
- `Views/` 只放展示和轻交互，不承载底层文件系统或 Git 逻辑
- `ViewModels/` 负责编排，不复制 `Service` 中的核心规则
- `Services/` 优先保持单一职责；跨多个能力的调度收敛到 `SkillManager`
- 新增路径、存储文件、配置项时，优先落在 `Utilities/Constants.swift`
- 不把临时调试逻辑、一次性脚本说明写进长期文档

## 测试要求
- 代码改动默认要补测试，尤其是：
  - 代理目录规则
  - lock file读写
  - symbolic link 判断
  - Git URL 解析与仓库扫描
  - Markdown / `SKILL.md` 解析
  - ViewModel 的状态转换
- 优先跑最小相关测试，再根据影响范围决定是否运行 `swift test`
- 不为未改动的旧问题顺手扩散修复；如发现，应单独说明

## 文档更新要求
以下改动必须同步文档：
- 修改用户可见行为：更新 `README.md` 或 `docs/roadmap.md`
- 修改实现结构、路径或迁移逻辑：更新 `docs/architecture.md`
- 修改命令、测试方法、开发流程：更新本文件
- 修改打包、发布、GitHub Actions、Homebrew：更新 `docs/release.md`

## 提交与 Review 约定
当前提交历史采用 Conventional Commits：
- `feat(...)`
- `fix(...)`
- `refactor(...)`
- `build(...)`
- `docs`

建议提交前自查：
- 代码是否有相邻测试用例支撑
- 文档是否仍然指向真实文件和真实命令
- 是否引入了新的路径分叉、配置漂移或未记录的行为变化

# 文档索引

当前文档体系以“**入口清晰、边界明确、内容贴近 implementation**”为目标，避免再出现大而全但逐步失真的说明文档。

## 阅读顺序
- `README.md`：项目概览、快速启动、文档入口
- `docs/architecture.md`：先理解真实实现、数据流和路径约定
- `docs/development.md`：再看本地开发、测试、提交流程
- `docs/release.md`：涉及打包、发布、Homebrew、自更新时再读
- `docs/roadmap.md`：确认哪些能力已经落地，哪些仍未实现

## 文档更新规则
- 改架构、路径、迁移、扫描、仓库同步、锁文件：更新 `docs/architecture.md`
- 改开发流程、测试方式、编码约束：更新 `docs/development.md`
- 改脚本、发布流程、产物名称、版本策略：更新 `docs/release.md`
- 改能力边界、已实现功能、明确未实现项：更新 `docs/roadmap.md`
- 改项目定位、启动方式、整体入口：更新 `README.md`

## 当前目录说明
- `docs/screenshots/`：文档插图资源
- 其余 Markdown 文件按主题平铺，避免深层目录导致检索成本升高

## 维护原则
- 文档描述必须以代码为准，不能复述历史设计
- 与实现脱节的旧文档应及时删除或重写，不做“archive 式保留”
- 如果一个信息只会维护一次，就只保留一个权威位置

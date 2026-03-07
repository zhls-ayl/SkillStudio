# SkillsMaster 对齐 `skills` 规范执行方案（修订版，可分阶段落地）

> 目标：将 SkillsMaster 在“可观察行为”上与 `skills` CLI（以 `skills/README.md` 与实现代码为准）对齐。优先关闭高风险不兼容点，再逐步补齐扩展能力。  
> 原则：**语义等价优先于实现细节一致**（可保留内部实现差异，但外部行为需一致）。

---

## 1. 背景与目标

当前 SkillsMaster 在 Agent 标识、安装作用域、Source 解析、Discovery 规则、internal 过滤、lock 兼容等方面与 `skills` CLI 存在偏差，导致：

- 同一仓库在 CLI 与 GUI 下结果不一致（能发现/能安装/安装到哪）
- 用户迁移时出现“看得到但装不上 / 装得上但后续更新异常”
- 上游新增 agent、字段、source 语法后兼容成本指数上升

本方案将修复拆为可独立验收、可回滚的阶段，且每阶段均要求测试证据。

---

## 2. 权威参考与对齐原则

### 2.1 规范来源（按优先级）

1. `skills/README.md`（用户可见语义）
2. `skills/src/*`（README 未覆盖或表述不清时，以实现为准）
3. SkillsMaster 当前实现：`SkillsMaster/Sources/SkillsMaster/`

### 2.2 对齐原则

- **可见行为对齐**：输入兼容、安装结果、发现结果、过滤结果、锁文件行为一致
- **可回滚优先**：高风险语义变更必须有 feature flag
- **增量迁移**：旧数据可读、迁移幂等、失败可恢复
- **测试先行**：每个规范条款至少 1 个自动化断言

### 2.3 本次范围（In Scope）

- Agent 标识与路径映射
- 安装作用域（Project / Global）语义 + canonical 目录语义
- Source 输入格式解析与安装入口
- Skill Discovery 顺序与 plugin manifest 语义
- `metadata.internal` + `INSTALL_INTERNAL_SKILLS` 语义
- 全局/项目锁文件行为（`.skill-lock.json` / `skills-lock.json`）
- lock 兼容写回（未知字段保留）
- 回归测试、迁移与发布策略

### 2.4 暂不纳入（Out of Scope）

- 一次性补齐全部 40+ agents 的完整 UI 体验（采用分批）
- 非核心视觉重构（仅做必要交互适配）

---

## 3. 差距清单（按优先级）

## P0（必须优先关闭）

1. **Agent 标识不一致（关键 alias 缺失）**
   - 当前状态：已完成第一阶段修复（2026-03-08）
   - 已对齐：`github-copilot`，`kiro-cli`
   - 已覆盖：显示名、筛选项、序列化值、旧值兼容读取 alias

2. **安装作用域语义不一致（Project/Global + canonical）**
   - 规范：默认 Project，`-g` 才 Global；存在 canonical + agent-specific 协同语义
   - 现状：以 `~/.skillsmaster/skills` 作为主要事实来源
   - 影响：目录布局、团队协作与 CLI 互操作不一致

3. **Source 解析覆盖不足**
   - 缺失/不完整：`tree` 子路径、GitLab `/-/tree`、本地路径、`owner/repo/path`、`owner/repo@skill`、well-known URL
   - 影响：常见来源输入在 GUI 下不可安装或安装结果偏差

4. **缺少 project lock 语义（`skills-lock.json`）**
   - 规范：project 安装写入 `skills-lock.json`
   - 现状：主要围绕全局 `.skill-lock.json`
   - 影响：项目级可追踪性与 CLI 行为不一致

## P1（高优先）

5. **Discovery 顺序偏离规范**
   - 规范：标准路径 + plugin manifest 优先；无结果再递归兜底
   - 现状：更接近全仓递归扫描
   - 影响：误检、漏检、性能与可解释性问题

6. **未实现 internal skill 过滤语义**
   - 规范：`metadata.internal: true` 默认隐藏，仅 `INSTALL_INTERNAL_SKILLS=1|true` 可见（显式 `--skill` 例外）
   - 现状：字段与过滤逻辑缺失

7. **SKILL.md 校验策略偏宽**
   - 规范：`name` / `description` 必填且类型合法
   - 现状：解析失败回退默认值，易产生“伪 skill”

8. **去重语义与 CLI 不一致**
   - CLI 发现阶段核心按名称去重（并非 `source + path + name`）
   - 当前按目录名/ID 聚合，跨源冲突处理不可控

9. **安装模式语义不完整（copy/symlink）**
   - 规范：支持 copy / symlink，且与作用域联动
   - 现状：缺少与 CLI 等价的模式语义与验收

## P2（中优先）

10. **lock 写回兼容性不足**
    - 现状：强结构化编码，未知字段 round-trip 丢失风险
    - 示例：`pluginName` 等扩展字段兼容

11. **文档与实现不一致**
    - 路径、scope、Agent 命名、功能状态描述存在偏差

---

## 4. 分阶段执行计划

## 阶段 0：基线与测试护栏（1 天）

### 目标

建立“规范条款 → 自动化断言”映射，确保后续改造可回归验证。

### 任务

- 新建规范对照清单：`SkillsMaster/docs/spec-compat-checklist.md`
- 建立测试矩阵（优先补缺口，再转红/转绿）：
  - Agent 标识映射与迁移（含旧值兼容）
  - scope + canonical + project/global 路径归属
  - source 解析金样例（见附录）
  - discovery 顺序与 fallback 触发条件
  - internal 过滤开关
  - `skills-lock.json` / `.skill-lock.json` 双锁行为
  - lock round-trip 未知字段保留

### 验收标准

- 每条 P0/P1 至少 1 条自动化测试
- 基线测试可稳定复现当前偏差
- checklist 可作为评审与发布准入清单

---

## 阶段 1：P0 语义闭环（2~3 天）

### 1. Agent 标识与路径映射修复

- [x] 将 `copilot-cli` 统一迁移到 `github-copilot`
- [x] 将 `kiro` 统一迁移到 `kiro-cli`
- [x] 统一 `AgentType`、显示名、筛选项、序列化值、兼容读取 alias
- [x] 内部 case 命名同步收敛为 `githubCopilot`、`kiroCLI`

### 2. 安装作用域与 canonical 语义对齐

- 明确作用域模型：`project`（默认）/ `global`
- 与 CLI 语义对齐：
  - project：项目目录下 canonical + agent 目录协同
  - global：用户目录下 canonical + agent 目录协同
- 若保留 `~/.skillsmaster/skills` 作为内部缓存，需保证其**不改变外部可观察语义**

### 3. Source 解析能力补齐

- 支持并测试：
  - `owner/repo`
  - `owner/repo/path/to/skill`
  - `owner/repo@skill-name`
  - `https://github.com/...`
  - `https://github.com/.../tree/<ref>/<subpath>`
  - `https://gitlab.com/...`
  - `https://gitlab.com/.../-/tree/<ref>/<subpath>`
  - `git@...`
  - `./local/path`
  - well-known URL
- 解析层拆分：
  - source 类型识别
  - clone URL 生成
  - optional `ref` / `subpath` / `skillFilter` 提取

### 4. project lock 行为补齐

- 引入/对齐 `skills-lock.json`（project scope）
- 与全局 `.skill-lock.json` 职责边界清晰

### 验收标准

- P0 测试全部通过
- source 金样例全通过
- project/global 安装路径与 lock 行为与 CLI 等价

---

## 阶段 2：P1 规则对齐（2~3 天）

### 1. Discovery 策略重构

- 实现“标准路径优先扫描”
- 支持 plugin manifest：
  - `.claude-plugin/marketplace.json`
  - `.claude-plugin/plugin.json`
- 仅在标准路径无结果时递归兜底

### 2. internal 语义实现

- `SkillMetadata` 增加 `metadata.internal`
- 读取 `INSTALL_INTERNAL_SKILLS`：
  - `1/true`：可见
  - 默认：隐藏
- 显式指定技能安装时支持“可见例外”语义（与 CLI 兼容）

### 3. SKILL.md 严格校验

- `name`、`description` 必填且类型合法
- 非法 frontmatter 不进入可安装集合（避免伪 skill）

### 4. 去重语义对齐

- 发现阶段优先对齐 CLI 规则（按名称去重）
- 对“同名不同源”冲突制定显式策略并给出 UI 提示（不 silently merge）

### 5. copy/symlink 模式补齐

- 与作用域、agent 组合行为一致
- 补齐关键交互与回归测试

### 验收标准

- discovery 顺序与 fallback 行为与 CLI 等价
- internal/strict-parse/去重策略均有测试覆盖
- copy/symlink 关键组合通过

---

## 阶段 3：兼容迁移与文档收敛（1~2 天）

### 1. lock round-trip 兼容写回

- 保留未知字段（包括未来新增字段）
- 最小化写回（仅改必要键）

### 2. 历史数据迁移

- agent 旧值迁移（含 alias 读取）
- 旧路径记录迁移（幂等、可回滚）
- cache / 配置兼容读取

### 3. 文档一致性修复

- 统一 README / docs 中路径、scope、术语、功能状态
- 补充迁移指南与故障排查

### 验收标准

- 迁移脚本幂等、失败可恢复
- lock round-trip 测试通过
- 文档描述与实际行为一致

---

## 阶段 4：扩展覆盖与发布（1~2 天）

### 1. Agent 覆盖补齐（分批）

- 第一批：高频 agents（含 `kiro-cli`、`github-copilot`，其中标识对齐已完成）
- 第二批：长尾 agents 增量纳入

### 2. E2E 验证

- 覆盖 `add/list/remove/check/update/find` 关键链路
- 覆盖 scope、agent 过滤、`--all`、copy/symlink、source 变体

### 3. 发布策略

- beta 灰度（默认开开关受控）
- 收集反馈后正式发布

### 验收标准

- E2E 通过率 ≥ 95%
- 无 P0/P1 回归

---

## 5. 推荐代码改造清单（文件级）

> 顺序：先语义核心层，再 UI 交互层。

- Agent 与路径：
  - `SkillsMaster/Sources/SkillsMaster/Models/AgentType.swift`
- Source 解析与扫描：
  - `SkillsMaster/Sources/SkillsMaster/Services/GitService.swift`
  - `SkillsMaster/Sources/SkillsMaster/Services/RepositoryManager.swift`
  - `SkillsMaster/Sources/SkillsMaster/Models/SkillRepository.swift`
- 安装与 scope/canonical：
  - `SkillsMaster/Sources/SkillsMaster/Services/SkillManager.swift`
  - `SkillsMaster/Sources/SkillsMaster/Services/SkillScanner.swift`
  - `SkillsMaster/Sources/SkillsMaster/Services/SymlinkManager.swift`
  - `SkillsMaster/Sources/SkillsMaster/Models/SkillScope.swift`
- metadata/internal + 严格校验：
  - `SkillsMaster/Sources/SkillsMaster/Models/SkillMetadata.swift`
  - `SkillsMaster/Sources/SkillsMaster/Services/SkillMDParser.swift`
- lock 与兼容：
  - `SkillsMaster/Sources/SkillsMaster/Models/LockEntry.swift`
  - `SkillsMaster/Sources/SkillsMaster/Services/LockFileManager.swift`
  - `SkillsMaster/Sources/SkillsMaster/Services/MigrationManager.swift`
  - （新增）project lock 管理模块（建议新增 `LocalLockManager`）
- 安装流程与交互：
  - `SkillsMaster/Sources/SkillsMaster/ViewModels/SkillInstallViewModel.swift`
  - `SkillsMaster/Sources/SkillsMaster/Views/Install/*`
- 文档与常量：
  - `SkillsMaster/Sources/SkillsMaster/Utilities/Constants.swift`
  - `SkillsMaster/README.md`
  - `SkillsMaster/docs/*`

---

## 6. 执行节奏建议（迭代拆分）

- **迭代 1（本周）**：阶段 0 + 阶段 1（P0 闭环）
- **迭代 2（下周）**：阶段 2（P1 规则对齐）
- **迭代 3（后续）**：阶段 3 + 阶段 4（兼容迁移 + 发布）

每次迭代均要求：

- 有测试通过证据（CI 可复现）
- 有可回滚方案（含开关）
- 有用户可见变更说明

---

## 7. 风险与回滚

## 主要风险

- 历史目录结构与新 scope/canonical 语义冲突
- 去重与严格校验上线后“可见技能数量变化”
- lock 升级导致旧数据读取异常
- agent 批量补齐引入回归面扩大

## 回滚策略

- 功能开关分批放量（scope/discovery/internal/strict-parse）
- 兼容窗口内保留旧读取逻辑（只读）
- 迁移前自动快照 lock 与关键配置
- 失败自动降级到旧路径/旧规则（可配置）

---

## 8. Definition of Done（DoD）

满足以下条件即视为本轮规范对齐完成：

- P0/P1 问题全部关闭并有自动化测试覆盖
- 安装、扫描、更新、删除行为与 `skills` 语义等价
- `metadata.internal` + plugin manifest 规则可用
- project/global 双锁语义可用（`skills-lock.json` / `.skill-lock.json`）
- lock round-trip 不丢未知字段
- 发布说明包含迁移、兼容与回滚指引

---

## 附录 A：Source 解析金样例（最低覆盖）

- `vercel-labs/agent-skills`
- `vercel-labs/agent-skills/skills/web-design-guidelines`
- `vercel-labs/agent-skills@web-design-guidelines`
- `https://github.com/vercel-labs/agent-skills`
- `https://github.com/vercel-labs/agent-skills/tree/main/skills/web-design-guidelines`
- `https://gitlab.com/org/repo`
- `https://gitlab.com/org/repo/-/tree/main/skills/foo`
- `git@github.com:vercel-labs/agent-skills.git`
- `./my-local-skills`
- `https://example.com`（well-known）


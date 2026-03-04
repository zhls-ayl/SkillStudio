import SwiftUI

/// AgentToggleView displays installation status toggles for skill on each Agent (F06)
///
/// One Toggle per Agent (switch), creates symlink when on, deletes when off
/// Inherited installation still shows source hint; user can toggle it off to remove source assignment
/// (except self-inherited cases such as Codex reading ~/.agents/skills directly)
struct AgentToggleView: View {

    let skill: Skill
    let viewModel: SkillDetailViewModel
    @Environment(SkillManager.self) private var skillManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(AgentType.allCases) { agentType in
                /// Find installation record for this Agent (may be direct installation or inherited)
                let installation = skill.installations.first { $0.agentType == agentType }
                let isInstalled = installation != nil
                /// Check if this is an inherited installation (from another Agent's directory)
                let isInherited = installation?.isInherited ?? false
                /// Some inheritance is "self-sourced" (e.g. Codex reading ~/.agents/skills directly).
                /// In this case there is no independent source Agent symlink to remove, so keep toggle disabled.
                let isSelfInherited = isInherited && installation?.inheritedFrom == agentType
                let agent = skillManager.agents.first { $0.type == agentType }
                let isAgentAvailable = agent?.isInstalled == true || agent?.configDirectoryExists == true

                HStack {
                    AgentIconView(agentType: agentType, size: 16)
                        .frame(width: 20)

                    Text(agentType.displayName)

                    Spacer()

                    // Inherited installation hint text: shows source path like "via ~/.claude/skills"
                    // Uses parentDirectoryDisplayPath derived from the actual installation path
                    if isInherited, let installation {
                        Text("via \(installation.parentDirectoryDisplayPath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !isAgentAvailable && !isInstalled {
                        Text("Not installed")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    // Toggle is macOS switch control (similar to Android's Switch)
                    // Inherited installations remain operable so users can continue turning OFF
                    // from direct-install state to inherited-source state in a second step.
                    Toggle("", isOn: Binding(
                        get: { isInstalled },
                        set: { _ in
                            Task {
                                await viewModel.toggleAgent(agentType, for: skill)
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    // disabled conditions:
                    // - Self-inherited installation has no removable source symlink (e.g. Codex shared directory)
                    // - Agent not installed and this skill not installed
                    .disabled(isSelfInherited || (!isAgentAvailable && !isInstalled))
                }
                .padding(.vertical, 2)
            }
        }
    }
}

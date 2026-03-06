import SwiftUI
import AppKit

/// AgentIconView renders the bundled SVG brand icon for an Agent.
/// Falls back to SF Symbol if the SVG resource cannot be loaded.
struct AgentIconView: View {

    let agentType: AgentType
    var size: CGFloat = 14

    var body: some View {
        Group {
            if let image = AgentIconLoader.image(for: agentType) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: agentType.iconName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Constants.AgentColors.color(for: agentType))
            }
        }
        .frame(width: size, height: size)
    }
}

private enum AgentIconLoader {
    private static var cache: [AgentType: NSImage] = [:]
    /// Cache negative lookups too, so unsupported SVG files are not retried every render pass.
    /// This mirrors memoization patterns in Java/Go (cache both hit and miss paths).
    private static var failed: Set<AgentType> = []

    static func image(for agentType: AgentType) -> NSImage? {
        // Some third-party SVG exports are not fully compatible with CoreSVG.
        // In practice, Kiro's upstream logo file triggers parser warnings
        // ("invalid rx/ry", malformed arc command counts) on each decode.
        // We intentionally skip loading that SVG and use the SF Symbol fallback
        // from AgentType.iconName to keep runtime logs clean and deterministic.
        if agentType == .kiro {
            failed.insert(agentType)
            return nil
        }

        if let cached = cache[agentType] {
            return cached
        }
        if failed.contains(agentType) {
            return nil
        }

        guard let iconURL = Bundle.module.url(
            forResource: agentType.iconResourceName,
            withExtension: "svg",
            subdirectory: "AgentIcons"
        ),
            let image = NSImage(contentsOf: iconURL)
        else {
            failed.insert(agentType)
            return nil
        }

        cache[agentType] = image
        return image
    }
}

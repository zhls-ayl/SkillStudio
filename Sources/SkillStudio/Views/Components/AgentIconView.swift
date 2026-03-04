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

    static func image(for agentType: AgentType) -> NSImage? {
        if let cached = cache[agentType] {
            return cached
        }

        guard let iconURL = Bundle.module.url(
            forResource: agentType.iconResourceName,
            withExtension: "svg",
            subdirectory: "AgentIcons"
        ),
            let image = NSImage(contentsOf: iconURL)
        else {
            return nil
        }

        cache[agentType] = image
        return image
    }
}

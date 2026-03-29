import SwiftUI
import AppKit

struct GlassBackground: View {
    @Environment(\.colorTheme) private var theme

    var body: some View {
        ThemedVisualEffect(theme: theme)
            .ignoresSafeArea()
    }
}

struct ThemedVisualEffect: NSViewRepresentable {
    var theme: ColorTheme

    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = materialForTheme(theme)
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = materialForTheme(theme)
    }

    private func materialForTheme(_ theme: ColorTheme) -> NSVisualEffectView.Material {
        switch theme {
        case .native, .warm:
            return .hudWindow
        case .frosted:
            return .underWindowBackground
        }
    }
}

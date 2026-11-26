import SwiftUI

@main
struct LaunchpadApp: App {
    var body: some Scene {
        WindowGroup {
            LaunchpadView()
                .frame(minWidth: 760, minHeight: 580)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

import SwiftUI

@main
struct PRApp: App {
    @StateObject private var project = EditorProject()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(project)
                .preferredColorScheme(.dark)
                .tint(PRTheme.accent)
        }
    }
}

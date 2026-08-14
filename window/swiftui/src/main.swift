import SwiftUI

// MARK: ContentView
struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 5/255, green: 0x44/255, blue: 0x5e/255)
                .ignoresSafeArea()

            Text("Hello macOS!")
                .font(.system(size: 48))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: BassieTestApp
@main
struct BassieTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 320, minHeight: 240)
        }
        .defaultSize(width: 1024, height: 768)
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

import SwiftUI

// MARK: ContentView
struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0x05 / 255.0, green: 0x44 / 255.0, blue: 0x5e / 255.0)
                .ignoresSafeArea()
            Text("Hello iOS!")
                .font(.system(size: 48))
                .foregroundColor(.primary)
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
                .onAppear {
                    NSLog("Hello iOS!")
                }
        }
    }
}

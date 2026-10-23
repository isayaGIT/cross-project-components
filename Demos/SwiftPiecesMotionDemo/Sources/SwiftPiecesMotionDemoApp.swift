import SwiftUI

@main
struct SwiftPiecesMotionDemoApp: App {
    var body: some Scene {
        WindowGroup {
            MotionDemoHome()
                .preferredColorScheme(.light)
        }
    }
}

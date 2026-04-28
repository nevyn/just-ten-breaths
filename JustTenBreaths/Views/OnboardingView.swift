import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState
    /// Called when the user clicks "Get Started" or closes the window.
    let onComplete: () -> Void

    @State private var page = 0
    @State private var navigatingForward = true

    private let pageCount = 2

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: welcomePage
                default: settingsPage
                }
            }
            .transition(.push(from: navigatingForward ? .trailing : .leading))
            .animation(.easeInOut(duration: 0.3), value: page)
            .frame(height: 600)

            Divider()

            // MARK: - Footer
            HStack {
                if page > 0 {
                    Button("Back") {
                        navigatingForward = false
                        page -= 1
                    }
                }

                Spacer()

                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                if page == 0 {
                    Button("Next") {
                        navigatingForward = true
                        page = 1
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Get Started") {
                        Task {
                            await appState.requestHealthKitAuthorizationIfNeeded()
                            onComplete()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 440)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Welcome to just ten breaths")
                .font(.largeTitle.bold())
            
            Group {
                Text("Remember to breathe. As you're coding, or doing other computer work with intense focus the entire day, you are tensing your body and pushing your mind for a very long time.")
                Text("Once an hour, the leaf in your menu bar will gently grab your attention. Notice it, get to it when you're ready to leave focus, and click it. The breathing flower can guide you through deep inhales for as long as you need it.")
                Text("Try to count your breaths, up to 10 if you are very busy, 20 if you're feeling ambitious. If you lose the count because your mind wandered with stress or over-activeness, start over from 1.")
                Text("Once you're able to count breaths to your goal, your jaw has unclenched, your shoulders have dropped, and the swirling stress in your mind has calmed a bit. Perhaps now, you'll have energy after work, too?")
            }
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Page 2: Settings

    private var settingsPage: some View {
        SettingsView(appState: appState)
    }
}

#Preview {
    OnboardingView(appState: AppState.previewInstance()) {}
}

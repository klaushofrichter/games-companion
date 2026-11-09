import SwiftUI

/// The companion's screens, swiped left and right: the games showcase and the
/// table's status. The board never depends on this phone; it only adds to it.
struct ContentView: View {
    enum Page: Int, CaseIterable { case games, table, screensaver }

    /// "page=table" or "page=screensaver" as a launch argument opens on that page (for screenshots).
    @State private var page: Page = {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("page=table") ? .table : args.contains("page=screensaver") ? .screensaver : .games
    }()
    @StateObject private var weather = Weather()
    @StateObject private var light = AmbientLight()

    var body: some View {
        GeometryReader { geo in
            // The pages run edge to edge (the showcase's backdrop fills the screen);
            // their content keeps clear of the notch, the home bar and the page dots.
            let insets = EdgeInsets(top: geo.safeAreaInsets.top, leading: 0,
                                    bottom: geo.safeAreaInsets.bottom + 26, trailing: 0)
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.12), Color(red: 0.02, green: 0.02, blue: 0.04)],
                               startPoint: .top, endPoint: .bottom)

                TabView(selection: $page) {
                    GamesPage(games: Game.catalog, insets: insets)
                        .tag(Page.games)
                    TablePage(weather: weather)
                        .padding(insets)
                        .tag(Page.table)
                        .onAppear { weather.start() }   // asks for location only once someone looks
                    ScreensaverPage()
                        .tag(Page.screensaver)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                    .opacity(page == .screensaver ? 0.3 : 1)

                // In a dark room, dim further than the screen's lowest brightness.
                Color.black
                    .opacity(light.veil)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 3), value: light.veil)
            }
            .ignoresSafeArea()
        }
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true   // it lies on the table as a display
            light.start()
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(Page.allCases, id: \.self) { p in
                Circle()
                    .fill(Color.white.opacity(p == page ? 0.85 : 0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, 4)
    }
}

#Preview {
    ContentView()
}

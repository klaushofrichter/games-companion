import SwiftUI

/// The companion's screens, swiped left and right: the games showcase and the
/// table's status. The board never depends on this phone; it only adds to it.
struct ContentView: View {
    enum Page: Int, CaseIterable { case games, table }

    /// "page=table" as a launch argument opens on the table page (for screenshots).
    @State private var page = ProcessInfo.processInfo.arguments.contains("page=table") ? Page.table : Page.games
    @StateObject private var weather = Weather()

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.12), Color(red: 0.02, green: 0.02, blue: 0.04)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            TabView(selection: $page) {
                GamesPage(games: Game.catalog)
                    .padding(.bottom, 26)
                    .tag(Page.games)
                TablePage(weather: weather)
                    .padding(.bottom, 26)
                    .tag(Page.table)
                    .onAppear { weather.start() }   // asks for location only once someone looks
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
        }
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true   // it lies on the table as a display
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

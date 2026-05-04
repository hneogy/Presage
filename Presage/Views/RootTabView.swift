import SwiftUI

struct RootTabView: View {
    @Environment(PariEngine.self) private var engine

    var body: some View {
        @Bindable var engine = engine

        ZStack(alignment: .bottom) {
            // Custom switcher (no SwiftUI TabView): iOS 26's TabView injects
            // a Liquid-Glass floating bar that bleeds past
            // .toolbar(.hidden, for: .tabBar). A simple ZStack of
            // NavigationStacks shows the same content with no system chrome.
            ZStack {
                NavigationStack { HomeView() }
                    .opacity(engine.activeTab == 0 ? 1 : 0)
                    .allowsHitTesting(engine.activeTab == 0)
                NavigationStack { PredictionListView() }
                    .opacity(engine.activeTab == 1 ? 1 : 0)
                    .allowsHitTesting(engine.activeTab == 1)
                NavigationStack { InsightsView() }
                    .opacity(engine.activeTab == 2 ? 1 : 0)
                    .allowsHitTesting(engine.activeTab == 2)
                NavigationStack { MoreView() }
                    .opacity(engine.activeTab == 3 ? 1 : 0)
                    .allowsHitTesting(engine.activeTab == 3)
            }
            .tint(DS.Palette.accent)

            ZStack(alignment: .bottom) {
                CustomTabBar(selection: $engine.activeTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                FloatingActionButton(
                    action: {
                        HapticService.light()
                        engine.showNewPrediction = true
                    },
                    longPressAction: {
                        engine.showQuickPredict = true
                    }
                )
                .offset(y: -34)
            }
        }
        .fullScreenCover(isPresented: $engine.showNewPrediction) {
            NewPredictionFlow()
        }
        .fullScreenCover(item: $engine.resolvingPrediction) { prediction in
            ResolutionFlow(prediction: prediction)
        }
        .sheet(isPresented: $engine.showQuickPredict) {
            QuickPredictSheet()
                .presentationDetents([.large])
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selection: Int

    private struct Tab {
        let title: String
        let icon: String
    }

    private let leftTabs: [Tab] = [
        Tab(title: "Home", icon: "house.fill"),
        Tab(title: "Predict", icon: "list.bullet"),
    ]

    private let rightTabs: [Tab] = [
        Tab(title: "Insights", icon: "chart.bar.fill"),
        Tab(title: "More", icon: "square.grid.2x2.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<leftTabs.count, id: \.self) { i in
                tabButton(index: i, tab: leftTabs[i])
            }

            // Space for the FAB
            Spacer().frame(width: 60)

            ForEach(0..<rightTabs.count, id: \.self) { i in
                tabButton(index: i + leftTabs.count, tab: rightTabs[i])
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(DS.Palette.surfaceSecondary)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(DS.Palette.separator, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        )
    }

    private func tabButton(index: Int, tab: Tab) -> some View {
        let isSelected = selection == index

        return Button {
            HapticService.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                selection = index
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .medium))
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .foregroundStyle(isSelected ? DS.Palette.darkSurfacePrimary : DS.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? DS.Palette.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

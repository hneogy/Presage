import SwiftUI
import SwiftData

struct TeamsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \TeamWorkspace.createdAt, order: .reverse)
    private var workspaces: [TeamWorkspace]

    @State private var showingNew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if workspaces.isEmpty {
                    emptyState
                } else {
                    ForEach(workspaces) { ws in
                        NavigationLink {
                            WorkspaceDetailView(workspace: ws)
                        } label: {
                            workspaceCard(ws)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(DS.Atmosphere.insights(colorScheme))
        .navigationTitle("Teams")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNew = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(DS.Palette.accent)
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NewWorkspaceSheet()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            WhisperLabel(text: "B2B · Présage for Teams")
            Text("Team Calibration")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.Palette.textPrimary)
                .kerning(-0.5)
            Text("Lock predictions about quarterly OKRs. Brier becomes the team KPI nobody can game.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Palette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
    }

    private var emptyState: some View {
        PariCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create your first workspace")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.Palette.textPrimary)
                Text("Add team members. Lock predictions about goals. Track everyone's calibration over time.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineSpacing(2)
                PariButton("New workspace") {
                    showingNew = true
                }
            }
        }
    }

    private func workspaceCard(_ ws: TeamWorkspace) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(ws.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                    Spacer()
                    Text("\(ws.members.count) member\(ws.members.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Palette.textTertiary)
                }
                Text("Owner: \(ws.ownerName)")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Palette.textSecondary)
            }
        }
    }
}

struct NewWorkspaceSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var ownerName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PariInput(placeholder: "Workspace name", text: $name)
                    PariInput(placeholder: "Your name", text: $ownerName)
                    PariButton("Create") {
                        let ws = TeamWorkspace(name: name, ownerName: ownerName)
                        context.insert(ws)
                        try? context.save()
                        dismiss()
                    }
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(DS.Palette.surfacePrimary)
            .navigationTitle("New workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Palette.textSecondary)
                }
            }
        }
    }
    private var canSave: Bool { name.count >= 2 && ownerName.count >= 2 }
}

struct WorkspaceDetailView: View {
    let workspace: TeamWorkspace
    @Environment(\.modelContext) private var context

    @Query private var teamPredictions: [TeamPrediction]

    private var workspacePredictions: [TeamPrediction] {
        teamPredictions.filter { $0.workspaceID == workspace.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(workspace.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DS.Palette.textPrimary)
                Text("Owner: \(workspace.ownerName)")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)

                Text("\(workspace.members.count) members · \(workspacePredictions.count) team predictions")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Palette.textTertiary)

                Text("This is a Tier-1 scaffold. The full workspace flow (locking confidences privately, revealing collectively at resolution, calibration leaderboard) ships in the v2 Teams release.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Palette.textTertiary)
                    .padding(.top, 18)
            }
            .padding(20)
        }
        .background(DS.Palette.surfacePrimary)
        .navigationTitle("Workspace")
        .navigationBarTitleDisplayMode(.inline)
    }
}

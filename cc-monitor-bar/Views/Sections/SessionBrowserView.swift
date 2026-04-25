import SwiftUI

/// 会话浏览器 — 基于 SQLite 持久化数据浏览历史会话
struct SessionBrowserView: View {
    @State private var sessions: [Session] = []
    @State private var selectedSession: Session?
    @State private var filterProject: String = "all"
    @State private var sortBy: SortOption = .recent
    @State private var isLoaded = false

    enum SortOption: String, CaseIterable {
        case recent = "最近"
        case tokens = "Token 用量"
        case messages = "消息数"
    }

    var filteredSessions: [Session] {
        var result = sessions
        if filterProject != "all" {
            result = result.filter { $0.projectId == filterProject }
        }
        switch sortBy {
        case .recent: break  // already sorted by started_at DESC
        case .tokens:
            result.sort { ($0.inputTokens + $0.outputTokens) > ($1.inputTokens + $1.outputTokens) }
        case .messages:
            result.sort { $0.messageCount > $1.messageCount }
        }
        return result
    }

    var projects: [String] {
        let ids = Set(sessions.map { $0.projectId })
        return ["all"] + ids.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 筛选栏
            HStack {
                Picker("项目", selection: $filterProject) {
                    ForEach(projects, id: \.self) { project in
                        Text(project == "all" ? "全部" : project).tag(project)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()

                Picker("排序", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()

                Text("\(filteredSessions.count) 个会话")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(Color.secondary.opacity(0.05))

            // 会话列表
            List(filteredSessions, id: \.id) { session in
                SessionBrowserRow(session: session)
                    .onTapGesture {
                        selectedSession = session
                    }
            }
        }
        .onAppear { loadSessions() }
        .sheet(item: $selectedSession) { session in
            SessionReplayView(session: session)
        }
    }

    private func loadSessions() {
        guard !isLoaded else { return }
        Task {
            do {
                sessions = try Repository().fetchRecentSessions(limit: 100)
                isLoaded = true
            } catch {
                print("加载会话列表失败: \(error)")
            }
        }
    }
}

struct SessionBrowserRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectPath.isEmpty ? "unknown" : session.projectPath)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(session.messageCount) msg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(session.durationFormatted)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.totalTokens.formattedTokens)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                HStack(spacing: 4) {
                    Text("↑\(session.inputTokens.formattedTokens)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("↓\(session.outputTokens.formattedTokens)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, DesignTokens.spacingXS)
    }
}


#Preview {
    SessionBrowserView()
        .frame(width: 500, height: 400)
}

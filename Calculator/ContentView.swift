import SwiftUI
import UIKit

private struct SnippetItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String

    init(id: UUID = UUID(), title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
    }
}

private struct ToolCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.68))
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SnippetComposer: View {
    @Binding var title: String
    @Binding var content: String
    let onSave: () -> Void

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("标题，例如：收货备注", text: $title)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                )
                .foregroundColor(.white)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.18))

                if content.isEmpty {
                    Text("内容，例如：您好，放门口即可，谢谢。")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $content)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 120)
                    .foregroundColor(.white)
                    .background(Color.clear)
            }
            .frame(minHeight: 120)

            Button(action: onSave) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("保存到快贴")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSave ? Color(red: 0.94, green: 0.61, blue: 0.18) : Color.white.opacity(0.10))
                .foregroundColor(canSave ? .black : Color.white.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(!canSave)
        }
    }
}

private struct SnippetRow: View {
    let item: SnippetItem
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(item.content)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.80))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(action: onCopy) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.26, green: 0.73, blue: 0.61))
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                }

                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("删除")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

struct ContentView: View {
    @State private var snippets = ContentView.defaultSnippets
    @State private var draftTitle = ""
    @State private var draftContent = ""
    @State private var selectedDate = Date()
    @State private var unixInput = ""
    @State private var parseError = ""
    @State private var currentTime = Date()
    @State private var feedbackMessage = ""
    @State private var feedbackToken = UUID()
    @State private var didLoadStoredSnippets = false

    private static let snippetStorageKey = "toolbox.savedSnippets"
    private static let defaultSnippets = [
        SnippetItem(title: "收货备注", content: "您好，放门口即可，谢谢。"),
        SnippetItem(title: "常用地址", content: "上海市浦东新区世纪大道 100 号 8 楼"),
        SnippetItem(title: "测试账号", content: "账号：demo@example.com\n密码：12345678")
    ]

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.10, blue: 0.20),
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.11, green: 0.16, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView {
                snippetsTab
                    .tabItem {
                        Image(systemName: "doc.on.clipboard")
                        Text("快贴")
                    }

                timestampsTab
                    .tabItem {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("时间")
                    }
            }
            .accentColor(Color(red: 0.94, green: 0.61, blue: 0.18))

            if !feedbackMessage.isEmpty {
                Text(feedbackMessage)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.75))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            loadSnippetsIfNeeded()
        }
        .onChange(of: snippets) { newValue in
            guard didLoadStoredSnippets else { return }
            saveSnippets(newValue)
        }
        .onReceive(timer) { date in
            currentTime = date
        }
    }

    private var snippetsTab: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ToolCard(
                        title: "文本快贴",
                        subtitle: "把常用回复、地址、账号、备注收进一个地方，点一下直接复制。"
                    ) {
                        Text("这一页的数据保存在本机，下次打开还在。适合收货备注、测试账号、常用命令、短信模板。")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ToolCard(title: "新增快贴", subtitle: "先做轻量版本，支持新增、删除和一键复制。") {
                        SnippetComposer(
                            title: $draftTitle,
                            content: $draftContent,
                            onSave: addSnippet
                        )
                    }

                    ToolCard(
                        title: "已保存内容",
                        subtitle: snippets.isEmpty ? "还没有内容，先添加一条。" : "共 \(snippets.count) 条，点击即可复制。"
                    ) {
                        if snippets.isEmpty {
                            Text("没有保存的快贴。")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.70))
                        } else {
                            VStack(spacing: 12) {
                                ForEach(snippets) { item in
                                    SnippetRow(
                                        item: item,
                                        onCopy: { copySnippet(item) },
                                        onDelete: { deleteSnippet(item) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color.clear)
            .navigationBarTitle("小工具箱", displayMode: .large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var timestampsTab: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ToolCard(
                        title: "当前时间",
                        subtitle: "本地时间每秒更新，常用值直接复制。"
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            timestampLine(title: "本地时间", value: fullDateFormatter.string(from: currentTime))
                            timestampLine(title: "Unix 秒", value: unixSecondsString(from: currentTime))
                            timestampLine(title: "Unix 毫秒", value: unixMillisecondsString(from: currentTime))
                            timestampLine(title: "ISO 8601", value: isoFormatter.string(from: currentTime))

                            HStack(spacing: 10) {
                                actionChip(title: "复制秒", systemImage: "doc.on.doc") {
                                    copy(text: unixSecondsString(from: currentTime), label: "已复制 Unix 秒")
                                }

                                actionChip(title: "复制毫秒", systemImage: "doc.on.doc.fill") {
                                    copy(text: unixMillisecondsString(from: currentTime), label: "已复制 Unix 毫秒")
                                }
                            }
                        }
                    }

                    ToolCard(
                        title: "日期转时间戳",
                        subtitle: "选一个时间，下面直接给你秒级和毫秒级。"
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            DatePicker(
                                "选择时间",
                                selection: $selectedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                            .padding(.vertical, 4)

                            timestampLine(title: "格式化时间", value: fullDateFormatter.string(from: selectedDate))
                            timestampLine(title: "Unix 秒", value: unixSecondsString(from: selectedDate))
                            timestampLine(title: "Unix 毫秒", value: unixMillisecondsString(from: selectedDate))

                            HStack(spacing: 10) {
                                actionChip(title: "复制格式化时间", systemImage: "calendar") {
                                    copy(text: fullDateFormatter.string(from: selectedDate), label: "已复制日期字符串")
                                }

                                actionChip(title: "复制秒时间戳", systemImage: "clock") {
                                    copy(text: unixSecondsString(from: selectedDate), label: "已复制时间戳")
                                }
                            }
                        }
                    }

                    ToolCard(
                        title: "时间戳转日期",
                        subtitle: "支持秒和毫秒。输入 10 位或 13 位都行。"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("输入时间戳", text: $unixInput)
                                .keyboardType(.numbersAndPunctuation)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.black.opacity(0.18))
                                )
                                .foregroundColor(.white)

                            HStack(spacing: 10) {
                                actionChip(title: "解析", systemImage: "arrow.clockwise.circle") {
                                    parseUnixInput()
                                }

                                actionChip(title: "填入当前秒", systemImage: "clock.badge.checkmark") {
                                    unixInput = unixSecondsString(from: currentTime)
                                    parseUnixInput()
                                }
                            }

                            if !parseError.isEmpty {
                                Text(parseError)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(red: 1.0, green: 0.62, blue: 0.62))
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color.clear)
            .navigationBarTitle("时间戳工具", displayMode: .large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func timestampLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.55))

            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionChip(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.10))
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
    }

    private func addSnippet() {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return }

        snippets.insert(SnippetItem(title: trimmedTitle, content: trimmedContent), at: 0)
        draftTitle = ""
        draftContent = ""
        copy(text: trimmedContent, label: "已保存并复制")
    }

    private func copySnippet(_ item: SnippetItem) {
        copy(text: item.content, label: "已复制 \(item.title)")
    }

    private func deleteSnippet(_ item: SnippetItem) {
        snippets.removeAll { $0.id == item.id }
        showFeedback("已删除 \(item.title)")
    }

    private func copy(text: String, label: String) {
        UIPasteboard.general.string = text
        showFeedback(label)
    }

    private func showFeedback(_ message: String) {
        let token = UUID()
        feedbackToken = token

        withAnimation(.easeInOut(duration: 0.18)) {
            feedbackMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard feedbackToken == token else { return }

            withAnimation(.easeInOut(duration: 0.18)) {
                feedbackMessage = ""
            }
        }
    }

    private func parseUnixInput() {
        let trimmed = unixInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parseError = "先输入一个时间戳。"
            return
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let rawValue = Double(normalized) else {
            parseError = "只能输入数字，支持秒或毫秒。"
            return
        }

        let secondsValue: Double
        if normalized.count >= 13 {
            secondsValue = rawValue / 1000
        } else {
            secondsValue = rawValue
        }

        let parsedDate = Date(timeIntervalSince1970: secondsValue)
        selectedDate = parsedDate
        parseError = ""
        copy(text: fullDateFormatter.string(from: parsedDate), label: "已解析并复制日期")
    }

    private func loadSnippetsIfNeeded() {
        guard !didLoadStoredSnippets else { return }
        didLoadStoredSnippets = true

        guard
            let data = UserDefaults.standard.data(forKey: Self.snippetStorageKey),
            let storedItems = try? JSONDecoder().decode([SnippetItem].self, from: data),
            !storedItems.isEmpty
        else {
            saveSnippets(snippets)
            return
        }

        snippets = storedItems
    }

    private func saveSnippets(_ items: [SnippetItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.snippetStorageKey)
    }

    private func unixSecondsString(from date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }

    private func unixMillisecondsString(from date: Date) -> String {
        String(Int(date.timeIntervalSince1970 * 1000))
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private var isoFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}

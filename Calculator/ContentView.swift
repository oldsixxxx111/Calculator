import SwiftUI

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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
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

private struct SummaryChip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.55))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RiskBadge: View {
    let risk: CleanupRisk

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: risk.iconName)
            Text(risk.shortLabel)
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(risk.color.opacity(0.16))
        .foregroundColor(risk.color)
        .clipShape(Capsule())
    }
}

private struct ResultRow: View {
    let result: ScanResult
    let formatter: ByteCountFormatter
    let dateFormatter: DateFormatter
    let onClean: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(result.purpose)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                RiskBadge(risk: result.risk)
            }

            statLine(title: "路径", value: result.path)
            statLine(title: "大小", value: formatter.string(fromByteCount: result.sizeBytes))
            statLine(title: "文件数", value: "\(result.fileCount)")

            if let newestDate = result.newestDate {
                statLine(title: "最近修改", value: dateFormatter.string(from: newestDate))
            }

            if result.isPartial {
                statLine(title: "扫描状态", value: "只统计了部分文件，目录太大。")
            }

            Text(result.insight)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Color.white.opacity(0.90))
                .fixedSize(horizontal: false, vertical: true)

            Text("删除影响：\(result.cleanupImpact)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(result.risk.color)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage = result.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !result.sampleChildren.isEmpty {
                Text("样本：\(result.sampleChildren.joined(separator: " · "))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if result.canClean {
                Button(action: onClean) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text("清理这一项")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(result.risk.color)
                    .foregroundColor(.black)
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

    private func statLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.50))

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ContentView: View {
    @StateObject private var model = CleanerViewModel()

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.16),
                    Color(red: 0.08, green: 0.13, blue: 0.12),
                    Color(red: 0.14, green: 0.11, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationView {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        summaryCard
                        analyzeCard

                        ForEach(CleanupRisk.allCases, id: \.self) { risk in
                            let filtered = model.results.filter { $0.risk == risk }
                            if !filtered.isEmpty {
                                ToolCard(title: risk.title, subtitle: risk.guidance) {
                                    VStack(spacing: 12) {
                                        ForEach(filtered) { result in
                                            ResultRow(
                                                result: result,
                                                formatter: byteFormatter,
                                                dateFormatter: dateFormatter,
                                                onClean: { model.clean(result) }
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        principleCard
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
                .background(Color.clear)
                .navigationBarTitle("清理顾问", displayMode: .large)
            }
            .navigationViewStyle(StackNavigationViewStyle())

            if !model.bannerMessage.isEmpty {
                Text(model.bannerMessage)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(.top, 12)
            }
        }
        .onAppear {
            if model.results.isEmpty {
                model.scan()
            }
        }
    }

    private var headerCard: some View {
        ToolCard(title: "AI 辅助清理顾问", subtitle: "本地扫描目录结构，先做风险分级，再给出删除建议。第一版只允许清理绿色安全项。") {
            VStack(alignment: .leading, spacing: 12) {
                Text("这不是盲删工具。它会把缓存、日志、临时文件和关键数据分开看，并把访问不到的目录单独标出来。")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    actionButton(
                        title: model.isScanning ? "扫描中..." : "开始扫描",
                        systemImage: "magnifyingglass.circle.fill",
                        filled: true,
                        enabled: !model.isScanning && !model.isCleaning,
                        action: { model.scan() }
                    )

                    actionButton(
                        title: model.isCleaning ? "清理中..." : "清理安全项",
                        systemImage: "trash.fill",
                        filled: false,
                        enabled: !model.isScanning && !model.isCleaning,
                        action: { model.cleanRecommended() }
                    )
                }

                if let lastScanDate = model.lastScanDate {
                    Text("上次扫描：\(dateFormatter.string(from: lastScanDate))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.55))
                }
            }
        }
    }

    private var summaryCard: some View {
        ToolCard(title: "扫描摘要", subtitle: "把空间、风险和权限问题先压成四个数字。") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    SummaryChip(title: "总占用", value: byteFormatter.string(fromByteCount: model.summary.totalBytes), color: Color(red: 0.36, green: 0.58, blue: 0.98))
                    SummaryChip(title: "可安全清理", value: byteFormatter.string(fromByteCount: model.summary.safeBytes), color: CleanupRisk.safe.color)
                }

                HStack(spacing: 10) {
                    SummaryChip(title: "需人工确认", value: byteFormatter.string(fromByteCount: model.summary.reviewBytes), color: CleanupRisk.review.color)
                    SummaryChip(title: "访问受限", value: "\(model.summary.inaccessibleCount) 项", color: CleanupRisk.inaccessible.color)
                }
            }
        }
    }

    private var analyzeCard: some View {
        ToolCard(title: "路径智能判读", subtitle: "把你看不懂的路径贴进来，我会按目录名和样本文件名给出用途、风险和删除影响。") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("例如：/var/mobile/Library/Caches/com.tencent.xin", text: $model.customPath)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
                    .foregroundColor(.white)

                actionButton(title: "生成判读", systemImage: "brain.head.profile", filled: false, enabled: true, action: {
                    model.analyzeCustomPath()
                })

                if let insight = model.customInsight {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(insight.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Spacer()
                            RiskBadge(risk: insight.risk)
                        }

                        Text(insight.explanation)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("删除影响：\(insight.cleanupImpact)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(insight.risk.color)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("置信度：\(insight.confidence)%")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.55))

                        if !insight.sampleChildren.isEmpty {
                            Text("样本：\(insight.sampleChildren.joined(separator: " · "))")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.52))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
                }
            }
        }
    }

    private var principleCard: some View {
        ToolCard(title: "清理原则", subtitle: "真正有用的不是自动删，而是先看懂目录。") {
            VStack(alignment: .leading, spacing: 10) {
                principleLine("绿色目录允许直接清理，但当前版本只删除目录内容，不删目录本身。")
                principleLine("黄色目录只给建议，不自动删，避免把离线资源和下载内容误删。")
                principleLine("红色目录默认按数据库、配置、聊天记录和用户文件处理。")
                principleLine("灰色目录表示访问不到，通常是权限不够、路径不存在，或需要更高权限。")
            }
        }
    }

    private func actionButton(title: String, systemImage: String, filled: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(filled ? (enabled ? Color(red: 0.96, green: 0.68, blue: 0.24) : Color.white.opacity(0.10)) : Color.white.opacity(enabled ? 0.10 : 0.06))
            .foregroundColor(filled ? (enabled ? .black : Color.white.opacity(0.45)) : (enabled ? .white : Color.white.opacity(0.40)))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(!enabled)
    }

    private func principleLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.70))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

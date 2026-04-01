import Foundation
import SwiftUI

final class CleanerViewModel: ObservableObject {
    @Published var results: [ScanResult] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var lastScanDate: Date?
    @Published var customPath = ""
    @Published var customInsight: CustomPathInsight?
    @Published var bannerMessage = ""

    var summary: ScanSummary {
        ScanSummary(
            totalBytes: results.reduce(0) { $0 + $1.sizeBytes },
            safeBytes: results.filter { $0.risk == .safe }.reduce(0) { $0 + $1.sizeBytes },
            reviewBytes: results.filter { $0.risk == .review }.reduce(0) { $0 + $1.sizeBytes },
            protectedBytes: results.filter { $0.risk == .protected }.reduce(0) { $0 + $1.sizeBytes },
            inaccessibleCount: results.filter { $0.risk == .inaccessible }.count
        )
    }

    var safeCandidates: [ScanResult] {
        results.filter { $0.canClean }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        let targets = defaultTargets()

        DispatchQueue.global(qos: .userInitiated).async {
            let scanned = targets.map { self.inspect(target: $0) }
            let sorted = scanned.sorted {
                if $0.risk.rawValue == $1.risk.rawValue {
                    return $0.sizeBytes > $1.sizeBytes
                }
                return $0.risk.rawValue < $1.risk.rawValue
            }

            DispatchQueue.main.async {
                self.results = sorted
                self.lastScanDate = Date()
                self.isScanning = false
                self.flash("扫描完成，共分析 \(sorted.count) 个目录")
            }
        }
    }

    func cleanRecommended() {
        let targets = safeCandidates
        guard !targets.isEmpty else {
            flash("当前没有可安全清理的目录")
            return
        }

        isCleaning = true

        DispatchQueue.global(qos: .userInitiated).async {
            var cleanedCount = 0

            for result in targets {
                do {
                    try self.removeContents(atPath: result.path)
                    cleanedCount += 1
                } catch {
                    continue
                }
            }

            DispatchQueue.main.async {
                self.isCleaning = false
                self.flash("已清理 \(cleanedCount) 项，建议重新扫描确认结果")
                self.scan()
            }
        }
    }

    func clean(_ result: ScanResult) {
        guard result.canClean, !isCleaning else { return }
        isCleaning = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.removeContents(atPath: result.path)
                DispatchQueue.main.async {
                    self.isCleaning = false
                    self.flash("已清理 \(result.title)")
                    self.scan()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCleaning = false
                    self.flash("清理失败：\(result.title)")
                }
            }
        }
    }

    func analyzeCustomPath() {
        let trimmedPath = customPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            flash("先输入一个目录路径")
            return
        }

        customInsight = explainPath(trimmedPath, sampleChildren: previewChildren(atPath: trimmedPath))
        flash("已生成路径判读")
    }

    private func defaultTargets() -> [ScanTarget] {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let tempPath = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).path

        return [
            ScanTarget(title: "当前应用缓存", path: home.appendingPathComponent("Library/Caches").path, purpose: "当前 app 的缓存内容，通常可重建。", risk: .safe, cleanupAllowed: true),
            ScanTarget(title: "当前应用临时目录", path: tempPath, purpose: "下载中间产物、导出缓存和临时文件。", risk: .safe, cleanupAllowed: true),
            ScanTarget(title: "当前应用日志", path: home.appendingPathComponent("Library/Logs").path, purpose: "调试日志和运行记录，通常不影响正常使用。", risk: .safe, cleanupAllowed: true),
            ScanTarget(title: "当前应用偏好设置", path: home.appendingPathComponent("Library/Preferences").path, purpose: "通常保存开关、配置和账号状态，不建议删除。", risk: .protected, cleanupAllowed: false),
            ScanTarget(title: "当前应用支持目录", path: home.appendingPathComponent("Library/Application Support").path, purpose: "常见于数据库、下载索引、离线资源和用户状态。", risk: .protected, cleanupAllowed: false),
            ScanTarget(title: "当前应用 Documents", path: home.appendingPathComponent("Documents").path, purpose: "通常是用户主动保存的数据，默认按重点保护处理。", risk: .protected, cleanupAllowed: false),
            ScanTarget(title: "系统 Crash 日志", path: "/var/mobile/Library/Logs/CrashReporter", purpose: "崩溃日志本身可删，但它对排错有帮助。", risk: .safe, cleanupAllowed: true),
            ScanTarget(title: "系统缓存", path: "/var/mobile/Library/Caches", purpose: "系统级缓存通常可重建，但误删会触发重新下载和重新索引。", risk: .review, cleanupAllowed: false)
        ]
    }

    private func inspect(target: ScanTarget) -> ScanResult {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: target.path, isDirectory: &isDirectory)

        guard exists else {
            return ScanResult(
                title: target.title,
                path: target.path,
                purpose: target.purpose,
                risk: .inaccessible,
                cleanupAllowed: false,
                sizeBytes: 0,
                fileCount: 0,
                newestDate: nil,
                sampleChildren: [],
                insight: "路径不存在，或当前运行环境没有能力看到这个目录。",
                cleanupImpact: "不执行任何清理。",
                isPartial: false,
                errorMessage: "如果你在普通沙盒下运行，看不到系统目录是正常的。"
            )
        }

        let url = URL(fileURLWithPath: target.path, isDirectory: isDirectory.boolValue)
        let sampledChildren = previewChildren(atPath: target.path)

        if !isDirectory.boolValue {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let explanation = explainPath(target.path, sampleChildren: sampledChildren)

            return ScanResult(
                title: target.title,
                path: target.path,
                purpose: target.purpose,
                risk: explanation.risk == .inaccessible ? target.risk : explanation.risk,
                cleanupAllowed: target.cleanupAllowed,
                sizeBytes: size,
                fileCount: size > 0 ? 1 : 0,
                newestDate: values?.contentModificationDate,
                sampleChildren: sampledChildren,
                insight: explanation.explanation,
                cleanupImpact: explanation.cleanupImpact,
                isPartial: false,
                errorMessage: nil
            )
        }

        do {
            let measurement = try measureDirectory(at: url)
            let explanation = explainPath(target.path, sampleChildren: measurement.sampleChildren)

            return ScanResult(
                title: target.title,
                path: target.path,
                purpose: target.purpose,
                risk: mergedRisk(base: target.risk, inferred: explanation.risk),
                cleanupAllowed: target.cleanupAllowed,
                sizeBytes: measurement.sizeBytes,
                fileCount: measurement.fileCount,
                newestDate: measurement.newestDate,
                sampleChildren: measurement.sampleChildren,
                insight: explanation.explanation,
                cleanupImpact: explanation.cleanupImpact,
                isPartial: measurement.isPartial,
                errorMessage: nil
            )
        } catch {
            return ScanResult(
                title: target.title,
                path: target.path,
                purpose: target.purpose,
                risk: .inaccessible,
                cleanupAllowed: false,
                sizeBytes: 0,
                fileCount: 0,
                newestDate: nil,
                sampleChildren: sampledChildren,
                insight: "目录存在，但当前权限无法完整读取内容。",
                cleanupImpact: "先不要删除，避免盲清。",
                isPartial: false,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func mergedRisk(base: CleanupRisk, inferred: CleanupRisk) -> CleanupRisk {
        if base == .inaccessible || inferred == .inaccessible { return .inaccessible }
        if base == .protected || inferred == .protected { return .protected }
        if base == .review || inferred == .review { return .review }
        return .safe
    }

    private func measureDirectory(at url: URL) throws -> (sizeBytes: Int64, fileCount: Int, newestDate: Date?, sampleChildren: [String], isPartial: Bool) {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants], errorHandler: { _, _ in true }) else {
            throw NSError(domain: "Cleaner", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建目录枚举器"])
        }

        var totalBytes: Int64 = 0
        var fileCount = 0
        var newestDate: Date?
        var sampleChildren: [String] = []
        var isPartial = false

        for case let childURL as URL in enumerator {
            if sampleChildren.count < 6 {
                sampleChildren.append(childURL.lastPathComponent)
            }

            let values = try childURL.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true {
                continue
            }

            if values.isRegularFile == true {
                totalBytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                fileCount += 1

                if let modified = values.contentModificationDate {
                    if newestDate == nil || modified > newestDate! {
                        newestDate = modified
                    }
                }
            }

            if fileCount >= 25000 {
                isPartial = true
                break
            }
        }

        return (totalBytes, fileCount, newestDate, sampleChildren, isPartial)
    }

    private func previewChildren(atPath path: String) -> [String] {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: path)
            return Array(items.prefix(6))
        } catch {
            return []
        }
    }

    private func explainPath(_ path: String, sampleChildren: [String]) -> CustomPathInsight {
        let lowercasedPath = path.lowercased()
        let joinedChildren = sampleChildren.joined(separator: " ").lowercased()

        func contains(_ terms: [String]) -> Bool {
            for term in terms where lowercasedPath.contains(term) || joinedChildren.contains(term) {
                return true
            }
            return false
        }

        if contains(["cache", "tmp", "temp", "crashreporter", "logs", ".log", ".tmp"]) {
            return CustomPathInsight(title: "偏向缓存或日志目录", risk: .safe, explanation: "路径名里出现了 cache、tmp、logs 或 crash 相关特征。这类内容通常是临时文件、崩溃日志、调试日志或可重建缓存，适合优先清理。", cleanupImpact: "通常只会让对应 App 重新生成缓存或重新下载缩略图，不会直接破坏主数据。", confidence: 86, sampleChildren: sampleChildren)
        }

        if contains(["download", "media", "webkit", "attachments", "inbox"]) {
            return CustomPathInsight(title: "偏向下载区或离线资源", risk: .review, explanation: "这个路径看起来像下载、媒体附件、Web 数据或导入目录。它们往往能释放不少空间，但也可能包含你还要用的离线资源。", cleanupImpact: "删除后可能触发重新下载、离线内容丢失或网页状态重建。", confidence: 72, sampleChildren: sampleChildren)
        }

        if contains(["application support", "documents", "preferences", ".plist", ".sqlite", "db", "database", "userdata"]) {
            return CustomPathInsight(title: "偏向关键数据目录", risk: .protected, explanation: "这个路径命中了 database、preferences、Application Support 或 Documents 等关键字。这里常放数据库、设置、聊天记录索引、账号状态和用户主动保存内容。", cleanupImpact: "误删后很可能导致登录丢失、历史记录消失、配置重置或应用崩溃。", confidence: 91, sampleChildren: sampleChildren)
        }

        return CustomPathInsight(title: "信息不足，建议人工确认", risk: .review, explanation: "仅从路径和样本文件名看不出它是否绝对安全。它可能是 App 自定义结构，也可能混合缓存与关键数据。", cleanupImpact: "建议先只清理明确标注为 cache、tmp、log 的内容，不要整个目录直接删空。", confidence: 54, sampleChildren: sampleChildren)
    }

    private func removeContents(atPath path: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return }

        if isDirectory.boolValue {
            let children = try fileManager.contentsOfDirectory(atPath: path)
            for child in children {
                let childPath = (path as NSString).appendingPathComponent(child)
                try fileManager.removeItem(atPath: childPath)
            }
        } else {
            try fileManager.removeItem(atPath: path)
        }
    }

    private func flash(_ message: String) {
        DispatchQueue.main.async {
            self.bannerMessage = message
            let token = message

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                if self.bannerMessage == token {
                    self.bannerMessage = ""
                }
            }
        }
    }
}

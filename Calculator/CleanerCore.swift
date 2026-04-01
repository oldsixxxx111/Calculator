import SwiftUI
import Foundation

enum CleanupRisk: Int, CaseIterable {
    case safe
    case review
    case protected
    case inaccessible

    var title: String {
        switch self {
        case .safe: return "可安全清理"
        case .review: return "需要人工确认"
        case .protected: return "重点保护"
        case .inaccessible: return "访问受限"
        }
    }

    var shortLabel: String {
        switch self {
        case .safe: return "安全"
        case .review: return "复查"
        case .protected: return "保护"
        case .inaccessible: return "受限"
        }
    }

    var color: Color {
        switch self {
        case .safe:
            return Color(red: 0.27, green: 0.77, blue: 0.57)
        case .review:
            return Color(red: 0.96, green: 0.68, blue: 0.24)
        case .protected:
            return Color(red: 0.94, green: 0.36, blue: 0.39)
        case .inaccessible:
            return Color(red: 0.54, green: 0.60, blue: 0.67)
        }
    }

    var iconName: String {
        switch self {
        case .safe: return "checkmark.shield"
        case .review: return "questionmark.circle"
        case .protected: return "lock.shield"
        case .inaccessible: return "nosign"
        }
    }

    var guidance: String {
        switch self {
        case .safe:
            return "通常是缓存、临时文件、崩溃日志，可重建。"
        case .review:
            return "可能是离线资源、Web 缓存或下载目录，删前确认。"
        case .protected:
            return "通常包含数据库、配置、聊天记录或用户文件。"
        case .inaccessible:
            return "当前权限下无法读取，或路径不存在。"
        }
    }
}

struct ScanTarget {
    let title: String
    let path: String
    let purpose: String
    let risk: CleanupRisk
    let cleanupAllowed: Bool
}

struct ScanResult: Identifiable {
    let id = UUID()
    let title: String
    let path: String
    let purpose: String
    let risk: CleanupRisk
    let cleanupAllowed: Bool
    let sizeBytes: Int64
    let fileCount: Int
    let newestDate: Date?
    let sampleChildren: [String]
    let insight: String
    let cleanupImpact: String
    let isPartial: Bool
    let errorMessage: String?

    var canClean: Bool {
        cleanupAllowed && risk == .safe && errorMessage == nil && sizeBytes > 0
    }
}

struct CustomPathInsight {
    let title: String
    let risk: CleanupRisk
    let explanation: String
    let cleanupImpact: String
    let confidence: Int
    let sampleChildren: [String]
}

struct ScanSummary {
    let totalBytes: Int64
    let safeBytes: Int64
    let reviewBytes: Int64
    let protectedBytes: Int64
    let inaccessibleCount: Int
}

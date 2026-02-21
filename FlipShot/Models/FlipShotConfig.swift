//
//  FlipShotConfig.swift
//  FlipShot
//
//  训练配置：组数、每组时长、视标类型等
//

import Foundation

/// 难度：决定每个视标停留时间（秒）
enum Difficulty: String, CaseIterable {
    case easy = "简单"   // 3.0 秒
    case normal = "普通" // 2.5 秒
    case hard = "挑战"   // 2.0 秒
    
    var cueInterval: TimeInterval {
        switch self {
        case .easy: return 3.0
        case .normal: return 2.5
        case .hard: return 2.0
        }
    }
}

struct FlipShotConfig {
    /// 组数（每组练完休息一次）
    var rounds: Int
    /// 每组训练时长（秒）
    var roundDuration: TimeInterval
    /// 组间休息时长（秒）
    var restDuration: TimeInterval
    /// 难度（决定每个视标停留时间）
    var difficulty: Difficulty
    /// 视标类型（E字表、字母表）
    var optotypeType: OptotypeType
    /// 视力表行（20/20, 20/30, 20/50等）
    var visionLine: VisionLine
    
    static let `default` = FlipShotConfig(
        rounds: 3,
        roundDuration: 30,
        restDuration: 10,
        difficulty: .normal,
        optotypeType: .mixed,  // E字+字母混合
        visionLine: .line20_50
    )
}

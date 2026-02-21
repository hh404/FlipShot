//
//  Optotype.swift
//  FlipShot
//
//  视标卡：标准视力表格式（20/20, 20/30, 20/50等）
//

import UIKit

/// 视标类型（标准视力表使用E字表 + 字母混合）
enum OptotypeType: String, CaseIterable {
    case eChart = "E字表"
    case mixed = "E字+字母混合"
}

/// E字方向
enum EDirection: CaseIterable {
    case up, down, left, right
    
    var rotation: CGFloat {
        switch self {
        case .right: return 0           // 开口向右（默认：竖线在左，横线向右）
        case .down: return .pi / 2      // 顺时针转90度，开口向下
        case .left: return .pi          // 转180度，开口向左
        case .up: return -.pi / 2       // 逆时针转90度，开口向上
        }
    }
    
    var name: String {
        switch self {
        case .up: return "上"
        case .down: return "下"
        case .left: return "左"
        case .right: return "右"
        }
    }
}

/// 单个视标
struct Optotype {
    let type: OptotypeType
    let visionLine: VisionLine
    
    // E字表
    var eDirection: EDirection?
    
    // 字母（大小写混合 A-Z）
    var letter: String?
    
    init(type: OptotypeType, visionLine: VisionLine, eDirection: EDirection? = nil, letter: String? = nil) {
        self.type = type
        self.visionLine = visionLine
        self.eDirection = eDirection
        self.letter = letter
    }
    
    static func random(type: OptotypeType, visionLine: VisionLine) -> Optotype {
        var optotype = Optotype(type: type, visionLine: visionLine, eDirection: nil, letter: nil)
        
        switch type {
        case .eChart:
            optotype.eDirection = EDirection.allCases.randomElement()
        case .mixed:
            // 50%概率是E字，50%概率是字母（大小写混合）
            if Bool.random() {
                optotype.eDirection = EDirection.allCases.randomElement()
            } else {
                // A-Z 大小写随机
                let isUppercase = Bool.random()
                let randomChar = Character(UnicodeScalar(Int.random(in: 65...90))!) // A-Z
                optotype.letter = isUppercase ? String(randomChar) : String(randomChar).lowercased()
            }
        }
        
        return optotype
    }
}

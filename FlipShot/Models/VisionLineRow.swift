//
//  VisionLineRow.swift
//  FlipShot
//
//  视力表：多行视标（标准格式）
//

import UIKit

/// 视力表行（标准Snellen格式）
enum VisionLine: String, CaseIterable {
    case line20_50 = "20/50"
    case line20_40 = "20/40"
    case line20_30 = "20/30"
    
    /// 视标高度（mm转pt）- 严格按照规范
    /// 1mm ≈ 2.83465 points (在72 DPI下)
    var optotypeHeight: CGFloat {
        switch self {
        case .line20_50: return 5.6 * 2.83465  // 5.6mm ≈ 15.87pt
        case .line20_40: return 4.5 * 2.83465  // 4.5mm ≈ 12.76pt
        case .line20_30: return 3.4 * 2.83465  // 3.4mm ≈ 9.64pt
        }
    }
    
    /// 单视标宽度（pt）- E字是正方形，宽度等于高度
    var optotypeWidth: CGFloat {
        return optotypeHeight
    }
    
    /// 笔画宽度（mm转pt）
    var strokeWidth: CGFloat {
        switch self {
        case .line20_50: return 1.4 * 2.83465  // 1.4mm ≈ 3.97pt
        case .line20_40: return 1.1 * 2.83465  // 1.1mm ≈ 3.12pt
        case .line20_30: return 0.85 * 2.83465  // 0.85mm ≈ 2.41pt
        }
    }
    
    /// 行间距（pt）- 约为视标高度的1.2倍
    var lineSpacing: CGFloat {
        return optotypeHeight * 1.2
    }
    
    /// 每行视标数量
    var optotypesPerRow: Int {
        return 5
    }
    
    /// 总行数
    var totalRows: Int {
        return 5
    }
    
    var displayName: String {
        return rawValue
    }
}

/// 完整的视力表（多行视标）
struct VisionChart {
    let visionLine: VisionLine
    let type: OptotypeType
    let rows: [[Optotype]]  // 多行，每行多个视标
    
    static func generate(type: OptotypeType, visionLine: VisionLine) -> VisionChart {
        var rows: [[Optotype]] = []
        
        for _ in 0..<visionLine.totalRows {
            var row: [Optotype] = []
            for _ in 0..<visionLine.optotypesPerRow {
                row.append(Optotype.random(type: type, visionLine: visionLine))
            }
            rows.append(row)
        }
        
        return VisionChart(visionLine: visionLine, type: type, rows: rows)
    }
}

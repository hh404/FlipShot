//
//  FixedVisionChart.swift
//  FlipShot
//
//  固定视力表：8行×5列（参考E字视标训练卡）
//

import UIKit

/// 固定视力表（8行×5列，共40格）
struct FixedVisionChart {
    let rows: Int = 8
    let cols: Int = 5
    let visionLine: VisionLine = .line20_50  // 固定20/50
    
    /// 所有视标（5行×8列）
    let optotypes: [[Optotype]]
    
    init() {
        // 生成固定的视标矩阵：全部都是E字，只是方向不同
        var optotypes: [[Optotype]] = []
        for _ in 0..<rows {
            var row: [Optotype] = []
            for _ in 0..<cols {
                // 全部都是E字，随机方向
                let optotype = Optotype(
                    type: .eChart,
                    visionLine: .line20_50,
                    eDirection: EDirection.allCases.randomElement(),
                    letter: nil
                )
                row.append(optotype)
            }
            optotypes.append(row)
        }
        self.optotypes = optotypes
    }
    
    /// 获取指定位置的视标
    func optotypeAt(row: Int, col: Int) -> Optotype? {
        guard row >= 0 && row < rows && col >= 0 && col < cols else { return nil }
        return optotypes[row][col]
    }
    
    /// 总视标数量
    var totalCount: Int {
        return rows * cols
    }
}

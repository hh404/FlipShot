//
//  MmScaler.swift
//  FlipShot
//
//  mm → points 精确转换工具（使用校准系数）
//

import UIKit

final class MmScaler {
    
    /// UserDefaults key for calibration factor (points per mm)
    private static let calibrationFactorKey = "calibrationFactorPtPerMm"
    
    /// 默认校准系数（基于 iPad Pro 12.9 6th gen: 264 PPI, scale 2.0）
    /// 计算：264 PPI / 25.4 mm/inch / 2.0 scale ≈ 5.19685 pt/mm
    private static let defaultCalibrationFactor: CGFloat = 5.19685
    
    /// 获取校准系数（points per mm）
    /// 如果未校准，返回默认值
    static func getCalibrationFactor() -> CGFloat {
        let factor = UserDefaults.standard.double(forKey: calibrationFactorKey)
        if factor > 0 {
            return CGFloat(factor)
        }
        return defaultCalibrationFactor
    }
    
    /// 保存校准系数
    static func setCalibrationFactor(_ factor: CGFloat) {
        UserDefaults.standard.set(factor, forKey: calibrationFactorKey)
    }
    
    /// 将毫米转换为 points（使用校准系数）
    /// - Parameter mm: 毫米值
    /// - Returns: points 值
    static func mmToPoints(_ mm: CGFloat) -> CGFloat {
        let factor = getCalibrationFactor()
        return mm * factor
    }
    
    /// 将 points 转换为毫米（用于显示）
    /// - Parameter points: points 值
    /// - Returns: 毫米值
    static func pointsToMm(_ points: CGFloat) -> CGFloat {
        let factor = getCalibrationFactor()
        return points / factor
    }
}

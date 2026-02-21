//
//  VisionCardImage.swift
//  FlipShot
//
//  训练卡原图对应的 40 个 E 方向（与 VisionCard 图片一致）
//

import Foundation

/// 原图训练卡 8 行×5 列，共 40 格。每格 E 的朝向（与图片从左到右、从上到下一致）
enum VisionCardImage {
    /// 资源名
    static let assetName = "VisionCard"
    
    /// 40 个格子的 E 方向（与训练卡图片一致：从左到右、从上到下）
    static let directions: [EDirection] = [
        .right, .right, .down,  .right, .down,   // 1-5
        .down,  .right, .left,  .right, .up,     // 6-10
        .right, .down,  .left,  .right, .right,  // 11-15
        .up,    .left,  .right, .down,  .right,  // 16-20
        .right, .left,  .up,    .right, .down,   // 21-25
        .right, .right, .left,  .right, .up,     // 26-30
        .down,  .right, .left,  .right, .right,  // 31-35
        .up,    .left,  .down,  .right, .right   // 36-40
    ]
    
    static let totalCount = 40
    static let rows = 8
    static let cols = 5
    
    /// 完成 2 行（10 格）后换眼
    static func shouldSwitchEye(atIndex index: Int) -> Bool {
        return index == 10
    }
}

//
//  TumblingEView.swift
//  FlipShot
//
//  向量绘制的 Tumbling E 视标（5×5 网格）
//

import UIKit

final class TumblingEView: UIView {
    
    private let sizeMm: CGFloat
    private var direction: EDirection {
        didSet {
            setNeedsDisplay()
        }
    }
    
    init(sizeMm: CGFloat, direction: EDirection) {
        self.sizeMm = sizeMm
        self.direction = direction
        super.init(frame: .zero)
        backgroundColor = .white
    }
    
    func updateDirection(_ newDirection: EDirection) {
        direction = newDirection
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 转换为 points（使用校准值）
        let totalHeightPoints = MmScaler.mmToPoints(sizeMm)
        let unit = totalHeightPoints / 5.0
        let strokeThickness = unit  // 1 unit
        
        // 计算 E 的尺寸（5 units wide × 5 units tall）
        let eWidth = unit * 5
        let eHeight = totalHeightPoints
        
        // 居中绘制
        let centerX = rect.midX
        let centerY = rect.midY
        
        context.saveGState()
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: direction.rotation)
        
        // 设置黑色填充，抗锯齿
        context.setFillColor(UIColor.black.cgColor)
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        // 绘制 E 字（5×5 网格）
        // 竖线（左侧，厚度 = 1 unit）
        let spineRect = CGRect(
            x: -eWidth / 2,
            y: -eHeight / 2,
            width: strokeThickness,
            height: eHeight
        )
        context.fill(spineRect)
        
        // 三条横线（每条厚度 = 1 unit，长度 = 5 units）
        // 顶部横线
        let topBarRect = CGRect(
            x: -eWidth / 2,
            y: -eHeight / 2,
            width: eWidth,
            height: strokeThickness
        )
        context.fill(topBarRect)
        
        // 中间横线（居中）
        let middleBarRect = CGRect(
            x: -eWidth / 2,
            y: -strokeThickness / 2,
            width: eWidth,
            height: strokeThickness
        )
        context.fill(middleBarRect)
        
        // 底部横线
        let bottomBarRect = CGRect(
            x: -eWidth / 2,
            y: eHeight / 2 - strokeThickness,
            width: eWidth,
            height: strokeThickness
        )
        context.fill(bottomBarRect)
        
        context.restoreGState()
    }
    
    override var intrinsicContentSize: CGSize {
        let height = MmScaler.mmToPoints(sizeMm)
        return CGSize(width: height, height: height)  // 正方形
    }
}

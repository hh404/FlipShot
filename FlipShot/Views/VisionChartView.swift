//
//  VisionChartView.swift
//  FlipShot
//
//  显示完整视力表：多行视标（5-6行，每行5-6个）
//

import UIKit

final class VisionChartView: UIView {
    
    private var chart: VisionChart?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white  // 白色背景
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func display(_ chart: VisionChart) {
        self.chart = chart
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let chart = chart else { return }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.cgColor)  // 黑色视标
        context.setStrokeColor(UIColor.black.cgColor)
        
        let visionLine = chart.visionLine
        let optotypeHeight = visionLine.optotypeHeight
        let optotypeWidth = visionLine.optotypeWidth
        let lineSpacing = visionLine.lineSpacing
        
        // 计算每行总宽度（5个视标 + 间距）
        let spacing = optotypeWidth  // 视标间距等于视标宽度
        let rowWidth = CGFloat(visionLine.optotypesPerRow) * optotypeWidth + CGFloat(visionLine.optotypesPerRow - 1) * spacing
        
        // 计算总高度（5行 + 行间距）
        let totalHeight = CGFloat(visionLine.totalRows) * optotypeHeight + CGFloat(visionLine.totalRows - 1) * lineSpacing
        
        // 居中绘制
        let startX = rect.midX - rowWidth / 2
        let startY = rect.midY - totalHeight / 2
        
        // 绘制每一行
        for (rowIndex, row) in chart.rows.enumerated() {
            let rowY = startY + CGFloat(rowIndex) * (optotypeHeight + lineSpacing)
            
            // 绘制这一行的每个视标
            for (colIndex, optotype) in row.enumerated() {
                let optotypeX = startX + CGFloat(colIndex) * (optotypeWidth + spacing)
                let center = CGPoint(
                    x: optotypeX + optotypeWidth / 2,
                    y: rowY + optotypeHeight / 2
                )
                
                // 全部都是E字（不再使用字母）
                if let direction = optotype.eDirection {
                    drawE(at: center, direction: direction, height: optotypeHeight, width: optotypeWidth, strokeWidth: visionLine.strokeWidth, context: context)
                }
            }
        }
    }
    
    /// 绘制E字（使用系统字体，通过旋转显示不同方向）
    private func drawE(at center: CGPoint, direction: EDirection, height: CGFloat, width: CGFloat, strokeWidth: CGFloat, context: CGContext) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: direction.rotation)
        
        // 使用系统字体绘制大写E，字体大小等于视标高度
        let font = UIFont.systemFont(ofSize: height, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black  // 纯黑色
        ]
        let attributedString = NSAttributedString(string: "E", attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: -textSize.width / 2,
            y: -textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        attributedString.draw(in: textRect)
        
        context.restoreGState()
    }
}

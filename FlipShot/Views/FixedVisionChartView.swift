//
//  FixedVisionChartView.swift
//  FlipShot
//
//  E字视标训练卡：8行×5列，每格有序号+E，细边框，符号小且不挤
//

import UIKit

final class FixedVisionChartView: UIView {
    
    private var chart: FixedVisionChart?
    private var currentRow: Int = 0
    private var currentCol: Int = 0
    
    /// 格子线宽
    private let cellBorderWidth: CGFloat = 0.5
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func display(_ chart: FixedVisionChart) {
        self.chart = chart
        self.currentRow = 0
        self.currentCol = -1
        setNeedsDisplay()
    }
    
    func highlightNext() -> (row: Int, col: Int, optotype: Optotype)? {
        guard let chart = chart else { return nil }
        
        currentCol += 1
        if currentCol >= chart.cols {
            currentCol = 0
            currentRow += 1
            if currentRow >= chart.rows {
                return nil
            }
        }
        
        setNeedsDisplay()
        guard let optotype = chart.optotypeAt(row: currentRow, col: currentCol) else { return nil }
        return (currentRow, currentCol, optotype)
    }
    
    func currentOptotype() -> Optotype? {
        guard let chart = chart else { return nil }
        return chart.optotypeAt(row: currentRow, col: currentCol)
    }
    
    func shouldSwitchEye() -> Bool {
        return currentRow >= 2 && currentCol == 0
    }
    
    override func draw(_ rect: CGRect) {
        guard let chart = chart else { return }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.cgColor)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(cellBorderWidth)
        
        // 网格：8行×5列，格子尽量接近正方形，整体居中
        let cols = chart.cols
        let rows = chart.rows
        let aspectChart = CGFloat(cols) / CGFloat(rows)
        let aspectRect = rect.width / rect.height
        
        var cellWidth: CGFloat
        var cellHeight: CGFloat
        var chartOriginX: CGFloat
        var chartOriginY: CGFloat

        if aspectRect > aspectChart {
            cellHeight = rect.height / CGFloat(rows)
            cellWidth = cellHeight
            let chartWidth = cellWidth * CGFloat(cols)
            chartOriginX = rect.midX - chartWidth / 2
            chartOriginY = rect.minY
        } else {
            cellWidth = rect.width / CGFloat(cols)
            cellHeight = cellWidth
            let chartHeight = cellHeight * CGFloat(rows)
            chartOriginX = rect.minX
            chartOriginY = rect.midY - chartHeight / 2
        }
        
        // 每格内：上边放序号，下边放E；E只占格子一部分，四周留白
        let numberHeight = cellHeight * 0.2   // 序号区域
        let eAreaHeight = cellHeight - numberHeight  // E 所在区域
        let padding = cellWidth * 0.25  // 格子内留白，避免挤在一起
        let eMaxSize = min(cellWidth, eAreaHeight) - 2 * padding  // E 最大尺寸
        
        for (rowIndex, row) in chart.optotypes.enumerated() {
            for (colIndex, optotype) in row.enumerated() {
                let cellX = chartOriginX + CGFloat(colIndex) * cellWidth
                let cellY = chartOriginY + CGFloat(rowIndex) * cellHeight
                let cellRect = CGRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight)
                
                // 画格子边框
                context.stroke(cellRect)
                
                // 序号 1–40
                let index = rowIndex * cols + colIndex + 1
                let numberFont = UIFont.systemFont(ofSize: numberHeight * 0.6, weight: .regular)
                let numberAttrs: [NSAttributedString.Key: Any] = [
                    .font: numberFont,
                    .foregroundColor: UIColor.black
                ]
                let numberStr = NSAttributedString(string: "\(index)", attributes: numberAttrs)
                let numberSize = numberStr.size()
                let numberRect = CGRect(
                    x: cellX + (cellWidth - numberSize.width) / 2,
                    y: cellY + (numberHeight - numberSize.height) / 2,
                    width: numberSize.width,
                    height: numberSize.height
                )
                numberStr.draw(in: numberRect)
                
                // E 画在格子下半部分中央，尺寸用 eMaxSize，不挤
                let eCenterX = cellX + cellWidth / 2
                let eCenterY = cellY + numberHeight + eAreaHeight / 2
                let eCenter = CGPoint(x: eCenterX, y: eCenterY)
                
                if let direction = optotype.eDirection {
                    drawE(at: eCenter, direction: direction, size: eMaxSize, context: context)
                }
            }
        }
    }
    
    /// 绘制E字（系统字体，旋转方向，纯黑）
    private func drawE(at center: CGPoint, direction: EDirection, size: CGFloat, context: CGContext) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: direction.rotation)
        
        let font = UIFont.systemFont(ofSize: size, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
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

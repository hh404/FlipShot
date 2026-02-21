//
//  EChartTrainingCardView.swift
//  FlipShot
//
//  E字视标训练卡：圆角白卡、黑边、标题 + 8×5 网格（序号 + E）
//  焦点与已验证仅通过数字样式区分，背景和 E 不变。
//

import UIKit

enum CellStatus {
    case unverified             // 未验证：黑色数字
    case verifying              // 当前焦点：等说方向词 → 加粗蓝框 + 数字蓝
    case correctWaitingSeparator // 答对了：等说「继续」→ 加粗绿框 + 数字绿
    case verified               // 已验证：数字灰色
}

final class EChartTrainingCardView: UIView {
    
    /// 40 格 E 的朝向，可由外部设置以支持刷新随机
    var directions: [EDirection] = VisionCardImage.directions {
        didSet { setNeedsDisplay() }
    }
    private let rows = VisionCardImage.rows
    private let cols = VisionCardImage.cols
    
    private let cornerRadius: CGFloat = 16
    private let borderWidth: CGFloat = 1
    private let gridLineWidth: CGFloat = 0.5
    private let headerHeight: CGFloat = 52
    private let cellHeight: CGFloat = 80
    private let cardHorizontalInset: CGFloat = 24
    private let cardVerticalInset: CGFloat = 20
    private let eSizeMm: CGFloat = 1.5
    
    private var cellStatuses: [CellStatus] = Array(repeating: .unverified, count: 40)
    private var currentVerifyingIndex: Int = -1
    
    func setStatus(_ status: CellStatus, forIndex index: Int) {
        guard index >= 0 && index < cellStatuses.count else { return }
        if status == .verifying {
            if currentVerifyingIndex >= 0 && currentVerifyingIndex < cellStatuses.count,
               cellStatuses[currentVerifyingIndex] != .verified {
                cellStatuses[currentVerifyingIndex] = .unverified
            }
            currentVerifyingIndex = index
        } else if status == .correctWaitingSeparator {
            currentVerifyingIndex = index
        } else if status == .verified && index == currentVerifyingIndex {
            currentVerifyingIndex = -1
        }
        cellStatuses[index] = status
        setNeedsDisplay()
    }
    
    func getStatus(forIndex index: Int) -> CellStatus {
        guard index >= 0 && index < cellStatuses.count else { return .unverified }
        return cellStatuses[index]
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let cardRect = rect.insetBy(dx: cardHorizontalInset, dy: cardVerticalInset)
        let cellWidth = cardRect.width / CGFloat(cols)
        
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)
        context.saveGState()
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(borderWidth)
        context.addPath(path.cgPath)
        context.strokePath()
        context.restoreGState()
        
        let titleRect = CGRect(x: cardRect.minX + 16, y: cardRect.minY + 12, width: cardRect.width - 32, height: headerHeight - 24)
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        let titleFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
        ("E字视标训练卡  20/50" as NSString).draw(in: titleRect, withAttributes: [
            .font: titleFont,
            .foregroundColor: UIColor.black,
            .paragraphStyle: titleStyle
        ])
        
        let gridOriginY = cardRect.minY + headerHeight
        let gridHeight = CGFloat(rows) * cellHeight
        
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(gridLineWidth)
        for r in 0...rows {
            let y = gridOriginY + CGFloat(r) * cellHeight
            context.move(to: CGPoint(x: cardRect.minX, y: y))
            context.addLine(to: CGPoint(x: cardRect.maxX, y: y))
        }
        for c in 0...cols {
            let x = cardRect.minX + CGFloat(c) * cellWidth
            context.move(to: CGPoint(x: x, y: gridOriginY))
            context.addLine(to: CGPoint(x: x, y: gridOriginY + gridHeight))
        }
        context.strokePath()
        
        let eHeightPoints = MmScaler.mmToPoints(eSizeMm)
        let unit = eHeightPoints / 5.0
        let eWidthPoints = unit * 5
        
        for index in 0..<(rows * cols) {
            let r = index / cols
            let c = index % cols
            let cellRect = CGRect(
                x: cardRect.minX + CGFloat(c) * cellWidth,
                y: gridOriginY + CGFloat(r) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
            let status = cellStatuses[index]
            
            // 只改数字：未验证黑、焦点蓝+圈、已验证灰
            let numStr = "\(index + 1)"
            let numFont = UIFont.systemFont(ofSize: 14, weight: .medium)
            let numStyle = NSMutableParagraphStyle()
            numStyle.alignment = .center
            
            let numColor: UIColor
            switch status {
            case .unverified: numColor = .black
            case .verifying: numColor = .systemBlue
            case .correctWaitingSeparator: numColor = .systemGreen
            case .verified: numColor = .systemGray
            }

            let numRect = CGRect(x: cellRect.minX, y: cellRect.minY + 6, width: cellRect.width, height: 24)

            // 当前焦点：数字外小圈（仅 verifying）
            if status == .verifying {
                let circleRadius: CGFloat = 10
                let circleCenter = CGPoint(x: cellRect.midX, y: cellRect.minY + 6 + 12)
                context.setStrokeColor(UIColor.systemBlue.cgColor)
                context.setLineWidth(1.5)
                context.strokeEllipse(in: CGRect(x: circleCenter.x - circleRadius, y: circleCenter.y - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
            }

            // 当前格子加粗边框：verifying = 蓝，correctWaitingSeparator = 绿
            if status == .verifying || status == .correctWaitingSeparator {
                let borderColor = status == .verifying ? UIColor.systemBlue.cgColor : UIColor.systemGreen.cgColor
                let cellBorderPath = UIBezierPath(rect: cellRect)
                context.setStrokeColor(borderColor)
                context.setLineWidth(3)
                context.addPath(cellBorderPath.cgPath)
                context.strokePath()
            }
            
            (numStr as NSString).draw(in: numRect, withAttributes: [
                .font: numFont,
                .foregroundColor: numColor,
                .paragraphStyle: numStyle
            ])
            
            // E 始终黑色，不随状态变化
            guard index < directions.count else { continue }
            let direction = directions[index]
            let eCenterX = cellRect.midX
            let eCenterY = cellRect.minY + 36 + eHeightPoints / 2
            
            context.saveGState()
            context.translateBy(x: eCenterX, y: eCenterY)
            context.rotate(by: direction.rotation)
            context.setFillColor(UIColor.black.cgColor)
            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
            
            let strokeThickness = unit
            let eWidth = eWidthPoints
            let eHeight = eHeightPoints
            context.fill(CGRect(x: -eWidth/2, y: -eHeight/2, width: strokeThickness, height: eHeight))
            context.fill(CGRect(x: -eWidth/2, y: -eHeight/2, width: eWidth, height: strokeThickness))
            context.fill(CGRect(x: -eWidth/2, y: -strokeThickness/2, width: eWidth, height: strokeThickness))
            context.fill(CGRect(x: -eWidth/2, y: eHeight/2 - strokeThickness, width: eWidth, height: strokeThickness))
            context.restoreGState()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let cardHeight = headerHeight + CGFloat(rows) * cellHeight
        return CGSize(width: UIView.noIntrinsicMetric, height: cardHeight + 2 * cardVerticalInset)
    }
}

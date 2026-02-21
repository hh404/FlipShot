//
//  RulerView.swift
//  FlipShot
//
//  校准标尺视图：左右端点竖线（2pt）+ 中间细线（1pt）
//

import UIKit

final class RulerView: UIView {
    
    private var lengthMm: CGFloat {
        didSet {
            setNeedsDisplay()
            invalidateIntrinsicContentSize()
        }
    }
    
    // 可选的校准系数，如果提供则使用此系数，否则使用MmScaler的当前系数
    private var calibrationFactor: CGFloat?
    
    init(lengthMm: CGFloat, calibrationFactor: CGFloat? = nil) {
        self.lengthMm = lengthMm
        self.calibrationFactor = calibrationFactor
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 转换为 points（使用指定的系数或当前MmScaler的系数）
        let factor = calibrationFactor ?? MmScaler.getCalibrationFactor()
        let lengthPoints = lengthMm * factor
        let centerY = rect.midY
        
        // 设置黑色
        context.setStrokeColor(UIColor.black.cgColor)
        context.setFillColor(UIColor.black.cgColor)
        
        // 左端点竖线（2pt宽）
        let leftEndpointRect = CGRect(
            x: 0,
            y: centerY - 20,
            width: 2,
            height: 40
        )
        context.fill(leftEndpointRect)
        
        // 右端点竖线（2pt宽）
        let rightEndpointRect = CGRect(
            x: lengthPoints - 2,
            y: centerY - 20,
            width: 2,
            height: 40
        )
        context.fill(rightEndpointRect)
        
        // 中间细线（1pt）
        let middleLineRect = CGRect(
            x: 0,
            y: centerY - 0.5,
            width: lengthPoints,
            height: 1
        )
        context.fill(middleLineRect)
    }
    
    override var intrinsicContentSize: CGSize {
        let factor = calibrationFactor ?? MmScaler.getCalibrationFactor()
        let width = lengthMm * factor
        return CGSize(width: width, height: 60)
    }
    
    func updateLength(_ newLengthMm: CGFloat) {
        lengthMm = newLengthMm
    }
    
    func updateCalibrationFactor(_ factor: CGFloat) {
        calibrationFactor = factor
        setNeedsDisplay()
        invalidateIntrinsicContentSize()
    }
}

//
//  CalibrationViewController.swift
//  FlipShot
//
//  校准屏幕：使用100mm物理标尺进行校准
//

import UIKit

final class CalibrationViewController: UIViewController {
    
    private let targetMm: CGFloat = 100.0
    private var displayedLengthMm: CGFloat = 100.0 {
        didSet {
            updateDisplay()
        }
    }
    
    // 保存校准前的系数，用于计算显示
    private var baseCalibrationFactor: CGFloat = MmScaler.getCalibrationFactor()
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "校准"
        l.font = .systemFont(ofSize: 36, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let instructionLabel: UILabel = {
        let l = UILabel()
        l.text = "把尺子放在屏幕上，\n调整直到两端刻度线间距正好是 100.0mm"
        l.font = .systemFont(ofSize: 20, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private lazy var rulerView: RulerView = {
        let v = RulerView(lengthMm: 100.0, calibrationFactor: baseCalibrationFactor)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let infoLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .medium)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let buttonStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 12
        s.distribution = .fillEqually
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private let doneButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("完成", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        b.backgroundColor = .systemGreen
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 16
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        // 初始显示目标长度（100mm），用户根据实际测量值调整
        displayedLengthMm = targetMm
        
        setupUI()
        updateDisplay()
        
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
    }
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(instructionLabel)
        view.addSubview(rulerView)
        view.addSubview(infoLabel)
        view.addSubview(buttonStack)
        view.addSubview(doneButton)
        
        // 创建6个调整按钮
        let buttonDeltas: [(title: String, delta: CGFloat)] = [
            ("-5mm", -5.0),
            ("-1mm", -1.0),
            ("-0.1mm", -0.1),
            ("+0.1mm", 0.1),
            ("+1mm", 1.0),
            ("+5mm", 5.0)
        ]
        
        for (title, delta) in buttonDeltas {
            let button = createAdjustButton(title: title, delta: delta)
            buttonStack.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            rulerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rulerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            rulerView.heightAnchor.constraint(equalToConstant: 60),
            infoLabel.topAnchor.constraint(equalTo: rulerView.bottomAnchor, constant: 32),
            infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            buttonStack.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 32),
            buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            buttonStack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            buttonStack.heightAnchor.constraint(equalToConstant: 50),
            doneButton.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 40),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 200),
            doneButton.heightAnchor.constraint(equalToConstant: 60),
        ])
    }
    
    private func createAdjustButton(title: String, delta: CGFloat) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        
        button.addAction(UIAction { [weak self] _ in
            self?.adjustLength(delta: delta)
        }, for: .touchUpInside)
        
        return button
    }
    
    private func adjustLength(delta: CGFloat) {
        displayedLengthMm += delta
        // 限制范围：50mm - 150mm
        displayedLengthMm = max(50.0, min(150.0, displayedLengthMm))
    }
    
    private func updateDisplay() {
        // 使用基准系数计算显示长度（避免循环依赖）
        let displayedLengthPoints = displayedLengthMm * baseCalibrationFactor
        
        // 更新标尺视图（使用基准系数）
        rulerView.updateCalibrationFactor(baseCalibrationFactor)
        rulerView.updateLength(displayedLengthMm)
        
        // 计算新校准系数（用于显示和保存）
        let calibrationFactor = displayedLengthPoints / targetMm
        
        // 实时保存校准系数
        MmScaler.setCalibrationFactor(calibrationFactor)
        
        // 更新信息显示
        #if DEBUG
        infoLabel.text = "目标长度：\(String(format: "%.1f", targetMm))mm\n当前长度：\(String(format: "%.2f", displayedLengthMm))mm\n校准系数：\(String(format: "%.4f", calibrationFactor)) pt/mm"
        #else
        infoLabel.text = "目标长度：\(String(format: "%.1f", targetMm))mm\n当前长度：\(String(format: "%.2f", displayedLengthMm))mm"
        #endif
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}

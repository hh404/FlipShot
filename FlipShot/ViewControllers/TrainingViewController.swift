//
//  TrainingViewController.swift
//  FlipShot
//
//  训练页：直接显示训练卡原图，逐个识别
//

import UIKit

final class TrainingViewController: UIViewController {
    
    private let config: FlipShotConfig
    private let roundIndex: Int
    
    var onDismiss: (() -> Void)?
    
    private var currentIndex: Int = -1
    private var waitingForAnswer = false
    
    private let progressLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24, weight: .medium)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let cardImageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let instructionLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 22, weight: .medium)
        l.textColor = .label
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let directionButtonsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 20
        s.distribution = .fillEqually
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private var upButton: UIButton!
    private var downButton: UIButton!
    private var leftButton: UIButton!
    private var rightButton: UIButton!
    
    init(config: FlipShotConfig, roundIndex: Int) {
        self.config = config
        self.roundIndex = roundIndex
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        cardImageView.image = UIImage(named: VisionCardImage.assetName)
        setupUI()
        startTraining()
    }
    
    private func setupUI() {
        view.addSubview(progressLabel)
        view.addSubview(cardImageView)
        view.addSubview(instructionLabel)
        view.addSubview(directionButtonsStack)
        
        upButton = createDirectionButton(title: "上", direction: .up)
        downButton = createDirectionButton(title: "下", direction: .down)
        leftButton = createDirectionButton(title: "左", direction: .left)
        rightButton = createDirectionButton(title: "右", direction: .right)
        
        directionButtonsStack.addArrangedSubview(upButton)
        directionButtonsStack.addArrangedSubview(downButton)
        directionButtonsStack.addArrangedSubview(leftButton)
        directionButtonsStack.addArrangedSubview(rightButton)
        
        // 图片原始尺寸：495×863
        let imageWidth: CGFloat = 495
        let imageHeight: CGFloat = 863
        
        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardImageView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 16),
            cardImageView.widthAnchor.constraint(equalToConstant: imageWidth),
            cardImageView.heightAnchor.constraint(equalToConstant: imageHeight),
            instructionLabel.topAnchor.constraint(equalTo: cardImageView.bottomAnchor, constant: 24),
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            directionButtonsStack.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 24),
            directionButtonsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            directionButtonsStack.widthAnchor.constraint(equalToConstant: 320),
            directionButtonsStack.heightAnchor.constraint(equalToConstant: 60),
            directionButtonsStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
        
        progressLabel.text = "第 \(roundIndex + 1) 组 / 共 \(config.rounds) 组"
    }
    
    private func createDirectionButton(title: String, direction: EDirection) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.tag = direction.hashValue
        button.addTarget(self, action: #selector(directionButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    private func startTraining() {
        currentIndex = -1
        showNextOptotype()
    }
    
    private func showNextOptotype() {
        currentIndex += 1
        
        if currentIndex >= VisionCardImage.totalCount {
            finishRound()
            return
        }
        
        waitingForAnswer = true
        let cellNumber = currentIndex + 1
        
        if VisionCardImage.shouldSwitchEye(atIndex: currentIndex) {
            instructionLabel.text = "已完成2行，请换另一只眼睛继续"
            VoiceManager.shared.speak("已完成2行，请换另一只眼睛继续")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.instructionLabel.text = "请看第 \(cellNumber) 个，说出方向"
                self?.speakCurrentDirection()
            }
        } else {
            instructionLabel.text = "请看第 \(cellNumber) 个，说出方向"
            speakCurrentDirection()
        }
    }
    
    private func speakCurrentDirection() {
        guard currentIndex >= 0, currentIndex < VisionCardImage.directions.count else { return }
        let direction = VisionCardImage.directions[currentIndex]
        VoiceManager.shared.sayOptotypeE(direction: direction)
    }
    
    @objc private func directionButtonTapped(_ sender: UIButton) {
        guard waitingForAnswer, currentIndex >= 0, currentIndex < VisionCardImage.directions.count else { return }
        
        let selectedDirection: EDirection?
        switch sender {
        case upButton: selectedDirection = .up
        case downButton: selectedDirection = .down
        case leftButton: selectedDirection = .left
        case rightButton: selectedDirection = .right
        default: selectedDirection = nil
        }
        
        guard let userDirection = selectedDirection else { return }
        let correctDirection = VisionCardImage.directions[currentIndex]
        let isCorrect = correctDirection == userDirection
        
        if isCorrect {
            instructionLabel.text = "✓ 正确！"
            VoiceManager.shared.speak("正确")
        } else {
            instructionLabel.text = "✗ 错误，正确答案是\(correctDirection.name)"
            VoiceManager.shared.speak("错误，正确答案是\(correctDirection.name)")
        }
        
        waitingForAnswer = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showNextOptotype()
        }
    }
    
    private func finishRound() {
        let isLastRound = (roundIndex + 1 >= config.rounds)
        if isLastRound {
            VoiceManager.shared.sayAllDone()
            let done = DoneViewController(config: config)
            done.modalPresentationStyle = .fullScreen
            done.onDismiss = { [weak self] in self?.dismissToRoot() }
            done.onAgain = { [weak self] config in
                self?.dismissToRootThenStartAgain(config: config)
            }
            present(done, animated: true)
        } else {
            VoiceManager.shared.sayRoundDone(current: roundIndex + 1, total: config.rounds)
            let rest = RestViewController(config: config, nextRoundIndex: roundIndex + 1)
            rest.modalPresentationStyle = .fullScreen
            rest.onDismiss = { [weak self] in self?.dismiss(animated: true) }
            present(rest, animated: true)
        }
    }
    
    private func dismissToRoot() {
        var vc: UIViewController? = self
        while vc?.presentingViewController != nil {
            vc = vc?.presentingViewController
        }
        vc?.dismiss(animated: true)
    }
    
    private func dismissToRootThenStartAgain(config: FlipShotConfig) {
        var vc: UIViewController? = self
        while vc?.presentingViewController != nil {
            vc = vc?.presentingViewController
        }
        vc?.dismiss(animated: true) {
            // 返回到根视图后，重新开始训练流程
            // 注意：这个旧的 TrainingViewController 流程现在不再被 HomeViewController 使用
            // 如果需要重新开始，应该导航到 PrepareViewController
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow),
                  let root = window.rootViewController else { return }
            var top = root
            while let next = top.presentedViewController { top = next }
            // 重新开始训练流程
            let prepare = PrepareViewController(config: config)
            prepare.modalPresentationStyle = .fullScreen
            top.present(prepare, animated: true)
        }
    }
}

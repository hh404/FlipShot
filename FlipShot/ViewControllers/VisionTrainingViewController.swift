//
//  VisionTrainingViewController.swift
//  FlipShot
//
//  训练：点「开始」自动开启语音识别，说出方向，答对后说「继续」
//

import UIKit
import AVFoundation

// MARK: - 当前激活题目状态（正式状态机）
enum TrainingItemState: Equatable {
    /// 识别原文为空，等待说方向（上/下/左/右）
    case waitingDirection
    /// 识别原文有内容，命中尚未更新（正在识别/处理中）
    case recognizing(transcript: String)
    /// 已命中且答对，等待说「继续」
    case answeredCorrectWaitingContinue
    /// 已命中但答错，可重说方向
    case answeredWrong
}

final class VisionTrainingViewController: UIViewController {
    
    /// 上方可滚动区域（可压缩），训练卡绝不压缩
    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.showsVerticalScrollIndicator = true
        s.alwaysBounceVertical = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let topContentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 10
        s.alignment = .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private let cardView: EChartTrainingCardView = {
        let v = EChartTrainingCardView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("返回", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let voiceDebugButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Voice调试", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    /// 刷新：打乱训练卡 E 的方向
    private lazy var refreshButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        b.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: config), for: .normal)
        b.tintColor = .systemBlue
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let instructionLabel: UILabel = {
        let l = UILabel()
        l.text = "说「上/下/左/右」答方向，答对后说「继续」进入下一题"
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// 距离指示条：在上下左右正上方，1/4 屏宽，绿=合适/黄=远一点/橙=近一点
    private let distanceBar: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGray5
        v.layer.cornerRadius = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    /// 指示条 + 上下左右 同一列，不单独占一行
    private let directionWithBarContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let voiceStatusLabel: UILabel = {
        let l = UILabel()
        l.text = "🎤 准备就绪"
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let readyIndicator: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGray
        v.layer.cornerRadius = 8
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let transcriptLabel: UILabel = {
        let l = UILabel()
        l.text = " "
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = .tertiaryLabel
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// 当前识别的关键字（上/下/左/右），每次更新随机颜色，连续两个相同方向也能看出是新一次识别
    private let keywordLabel: UILabel = {
        let l = UILabel()
        l.text = " "
        l.font = .systemFont(ofSize: 20, weight: .bold)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// 当前题目状态横幅：明显展示 等待方向 / 识别中 / 正确待继续 / 错误
    private let stateBannerContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 12
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let stateBannerLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textAlignment = .center
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let startButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("开始训练", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        b.backgroundColor = .systemGreen
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let directionButtonsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 16
        s.distribution = .fillEqually
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    /// 开始按钮行：开始 + 指示灯 + 状态 + 方向按钮
    private let startRowStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 12
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private var upButton: UIButton!
    private var downButton: UIButton!
    private var leftButton: UIButton!
    private var rightButton: UIButton!
    
    private var currentVerifyingIndex: Int = -1
    private let totalCount = VisionCardImage.totalCount
    private var isVoiceRecognitionEnabled = false
    private var currentCellVerified = false
    /// 当前训练卡 40 格 E 的方向（刷新时打乱）
    private var trainingDirections: [EDirection] = VisionCardImage.directions.shuffled()

    private let distanceMonitor = DeviceDistanceMonitor()
    /// 上次已显示的距离区间，区间未变不刷新指示条，避免闪烁
    private var lastDistanceZone: DistanceZone?

    /// 进入训练页时自动提高亮度，离开时恢复
    private var savedBrightness: CGFloat?

    /// 状态机：用于推导 TrainingItemState
    private var currentTranscript: String = ""
    private var isProcessingVoice: Bool = false
    private var lastAnswerWasWrong: Bool = false

    /// 当前激活题目的状态（无激活题目时为 nil）
    private var trainingState: TrainingItemState? {
        guard currentVerifyingIndex >= 0 else { return nil }
        if currentCellVerified { return .answeredCorrectWaitingContinue }
        let t = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if lastAnswerWasWrong && t.isEmpty { return .answeredWrong }
        if lastAnswerWasWrong && !t.isEmpty { return .recognizing(transcript: t) }
        if !t.isEmpty { return .recognizing(transcript: t) }
        return .waitingDirection
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        
        view.addSubview(backButton)
        view.addSubview(refreshButton)
        view.addSubview(voiceDebugButton)
        stateBannerContainer.addSubview(stateBannerLabel)
        directionWithBarContainer.addSubview(distanceBar)
        directionWithBarContainer.addSubview(directionButtonsStack)
        startRowStack.addArrangedSubview(startButton)
        startRowStack.addArrangedSubview(readyIndicator)
        startRowStack.addArrangedSubview(voiceStatusLabel)
        startRowStack.addArrangedSubview(directionWithBarContainer)
        upButton = createDirectionButton(title: "上", direction: .up)
        downButton = createDirectionButton(title: "下", direction: .down)
        leftButton = createDirectionButton(title: "左", direction: .left)
        rightButton = createDirectionButton(title: "右", direction: .right)
        directionButtonsStack.addArrangedSubview(upButton)
        directionButtonsStack.addArrangedSubview(downButton)
        directionButtonsStack.addArrangedSubview(leftButton)
        directionButtonsStack.addArrangedSubview(rightButton)

        topContentStack.addArrangedSubview(instructionLabel)
        topContentStack.addArrangedSubview(startRowStack)
        topContentStack.addArrangedSubview(keywordLabel)
        topContentStack.addArrangedSubview(stateBannerContainer)
        topContentStack.addArrangedSubview(transcriptLabel)
        scrollView.addSubview(topContentStack)
        view.addSubview(scrollView)
        view.addSubview(cardView)

        startButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        startButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        readyIndicator.widthAnchor.constraint(equalToConstant: 16).isActive = true
        readyIndicator.heightAnchor.constraint(equalToConstant: 16).isActive = true
        directionButtonsStack.widthAnchor.constraint(equalToConstant: 280).isActive = true
        directionButtonsStack.heightAnchor.constraint(equalToConstant: 50).isActive = true
        distanceBar.heightAnchor.constraint(equalToConstant: 14).isActive = true
        NSLayoutConstraint.activate([
            distanceBar.topAnchor.constraint(equalTo: directionWithBarContainer.topAnchor),
            distanceBar.leadingAnchor.constraint(equalTo: directionWithBarContainer.leadingAnchor),
            distanceBar.trailingAnchor.constraint(equalTo: directionWithBarContainer.trailingAnchor),
            directionButtonsStack.topAnchor.constraint(equalTo: distanceBar.bottomAnchor, constant: 6),
            directionButtonsStack.leadingAnchor.constraint(equalTo: directionWithBarContainer.leadingAnchor),
            directionButtonsStack.trailingAnchor.constraint(equalTo: directionWithBarContainer.trailingAnchor),
            directionButtonsStack.bottomAnchor.constraint(equalTo: directionWithBarContainer.bottomAnchor),
        ])
        stateBannerLabel.topAnchor.constraint(equalTo: stateBannerContainer.topAnchor, constant: 14).isActive = true
        stateBannerLabel.leadingAnchor.constraint(equalTo: stateBannerContainer.leadingAnchor, constant: 16).isActive = true
        stateBannerLabel.trailingAnchor.constraint(equalTo: stateBannerContainer.trailingAnchor, constant: -16).isActive = true
        stateBannerLabel.bottomAnchor.constraint(equalTo: stateBannerContainer.bottomAnchor, constant: -14).isActive = true

        cardView.directions = trainingDirections

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            refreshButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 16),
            voiceDebugButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            voiceDebugButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: cardView.topAnchor, constant: -8),

            topContentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            topContentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            topContentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            topContentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            topContentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),

            cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            cardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        voiceDebugButton.addTarget(self, action: #selector(voiceDebugTapped), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        upButton.addTarget(self, action: #selector(directionButtonTapped(_:)), for: .touchUpInside)
        downButton.addTarget(self, action: #selector(directionButtonTapped(_:)), for: .touchUpInside)
        leftButton.addTarget(self, action: #selector(directionButtonTapped(_:)), for: .touchUpInside)
        rightButton.addTarget(self, action: #selector(directionButtonTapped(_:)), for: .touchUpInside)
        
        stateBannerContainer.isHidden = true
        setupVoiceRecognition()
        setupDistanceMonitor()
    }

    private func setupDistanceMonitor() {
        distanceMonitor.onUpdate = { [weak self] reading in
            DispatchQueue.main.async {
                self?.updateDistanceLabel(reading)
            }
        }
    }

    /// 先确认相机权限再启动测距，避免无权限时触发 Fig 报错；模拟器不启测距
    private func startDistanceMonitorIfAuthorized() {
        #if targetEnvironment(simulator)
        updateDistanceLabel(DistanceReading(distanceCM: nil, inRange: false, method: "仅真机测距"))
        return
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            distanceMonitor.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.distanceMonitor.start()
                    } else {
                        self?.updateDistanceLabel(DistanceReading(distanceCM: nil, inRange: false, method: "需摄像头权限"))
                    }
                }
            }
        case .denied, .restricted:
            updateDistanceLabel(DistanceReading(distanceCM: nil, inRange: false, method: "需摄像头权限"))
        @unknown default:
            distanceMonitor.start()
        }
    }

    /// 仅用指示条颜色：绿=合适，黄=远一点，橙=近一点；区间未变不刷新，避免闪烁
    private func updateDistanceLabel(_ reading: DistanceReading) {
        let zone = reading.zone
        guard zone != lastDistanceZone else { return }
        lastDistanceZone = zone
        switch zone {
        case .unknown:
            distanceBar.backgroundColor = .systemGray5
        case .tooClose, .slightlyClose:
            distanceBar.backgroundColor = .systemYellow
        case .good:
            distanceBar.backgroundColor = .systemGreen
        case .slightlyFar, .tooFar:
            distanceBar.backgroundColor = .systemOrange
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 自动提高屏幕亮度便于看清 E 字视标，离开时恢复
        savedBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
        startDistanceMonitorIfAuthorized()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 恢复进入训练页前的屏幕亮度
        if let saved = savedBrightness {
            UIScreen.main.brightness = saved
            savedBrightness = nil
        }
        distanceMonitor.stop()
    }

    private func setupVoiceRecognition() {
        let recognizer = VoiceCommandRecognizer.shared
        recognizer.onTranscript = { [weak self] text, isFinal in
            let tag = isFinal ? "识别" : "识别(中)"
            print("🎤 \(tag): \(text)")
            DispatchQueue.main.async {
                guard let self else { return }
                self.currentTranscript = text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.lastAnswerWasWrong = false
                }
                self.transcriptLabel.text = text.isEmpty ? " " : "「\(text)」"
                self.transcriptLabel.textColor = isFinal ? .secondaryLabel : .tertiaryLabel
                self.updateTrainingStateUI()
            }
        }
        recognizer.onProcessing = { [weak self] isProcessing in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isProcessingVoice = isProcessing
                if isProcessing {
                    if let t = self.transcriptLabel.text, !t.contains("正在处理中") {
                        self.transcriptLabel.text = t + " 正在处理中…"
                    }
                } else {
                    self.transcriptLabel.text = self.transcriptLabel.text?.replacingOccurrences(of: " 正在处理中…", with: "")
                }
                self.updateTrainingStateUI()
            }
        }
        recognizer.onCommand = { [weak self] command in
            guard command.isSeparator else { return }
            DispatchQueue.main.async {
                print("📱 收到语音: \(command.display)，下一题")
                self?.moveToNextCell()
            }
        }
        recognizer.onDirectionCommand = { [weak self] command in
            guard command.isDirection, let direction = Self.edirection(from: command) else { return }
            DispatchQueue.main.async {
                print("📱 收到语音方向: \(direction.name)")
                self?.showKeyword(command.display)
                self?.handleDirectionInput(direction, autoAdvance: false)
            }
        }
        recognizer.onCueStateChanged = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateRecognitionStatus(VoiceCommandRecognizer.shared.isRecognizing)
            }
        }
    }

    private static func edirection(from command: VoiceCommandRecognizer.Command) -> EDirection? {
        switch command {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .continue, .next: return nil
        }
    }

    private static let keywordColors: [UIColor] = [
        .systemRed, .systemOrange, .systemGreen, .systemBlue, .systemPurple,
        .systemPink, .systemTeal, .systemIndigo
    ]

    private func showKeyword(_ keyword: String) {
        keywordLabel.text = "当前: \(keyword)"
        keywordLabel.textColor = Self.keywordColors.randomElement() ?? .label
    }

    private func createDirectionButton(title: String, direction: EDirection) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }
    
    @objc private func startTapped() {
        startButton.isEnabled = false
        startButton.alpha = 0.5
        if VoiceCommandRecognizer.shared.isRecognizing {
            resetVoiceGameStateAndStartRound()
        } else {
            startVoiceRecognition()
        }
    }
    
    /// 语音已常开时「重新开始」：只重置格子与状态，不关/开识别
    private func resetVoiceGameStateAndStartRound() {
        for i in 0..<totalCount {
            cardView.setStatus(.unverified, forIndex: i)
        }
        currentVerifyingIndex = 0
        currentCellVerified = false
        currentTranscript = ""
        lastAnswerWasWrong = false
        cardView.setStatus(.verifying, forIndex: 0)
        VoiceCommandRecognizer.shared.clearForNextInput()
        updateTrainingStateUI()
    }
    
    private func startVoiceRecognition() {
        let recognizer = VoiceCommandRecognizer.shared
        recognizer.onPermissionChanged = { [weak self] micGranted, speechGranted in
            guard let self else { return }
            DispatchQueue.main.async {
                guard micGranted && speechGranted else {
                    self.showAlert(title: "需要权限", message: "请在设置中允许麦克风和语音识别权限")
                    self.startButton.isEnabled = true
                    self.startButton.alpha = 1.0
                    return
                }
                recognizer.onErrorText = { [weak self] message in
                    DispatchQueue.main.async {
                        self?.showAlert(title: "语音识别启动失败", message: message)
                        self?.startButton.isEnabled = true
                        self?.startButton.alpha = 1.0
                    }
                }
                recognizer.start()
                if recognizer.isRecognizing {
                    self.isVoiceRecognitionEnabled = true
                    self.currentVerifyingIndex = 0
                    self.currentCellVerified = false
                    self.currentTranscript = ""
                    self.lastAnswerWasWrong = false
                    self.cardView.setStatus(.verifying, forIndex: 0)
                    recognizer.clearForNextInput()
                    self.updateTrainingStateUI()
                } else {
                    self.startButton.isEnabled = true
                    self.startButton.alpha = 1.0
                }
            }
        }
        recognizer.requestPermissions()
    }
    
    @objc private func directionButtonTapped(_ sender: UIButton) {
        let selectedDirection: EDirection?
        switch sender {
        case upButton: selectedDirection = .up
        case downButton: selectedDirection = .down
        case leftButton: selectedDirection = .left
        case rightButton: selectedDirection = .right
        default: selectedDirection = nil
        }
        guard let direction = selectedDirection else { return }
        handleDirectionInput(direction, autoAdvance: true)
    }
    
    private func handleDirectionInput(_ direction: EDirection, autoAdvance: Bool) {
        print("🎯 处理方向输入: \(direction.name), 当前索引: \(currentVerifyingIndex), 自动前进: \(autoAdvance)")
        
        guard currentVerifyingIndex >= 0 else {
            print("⚠️ 当前没有正在验证的格子")
            return
        }
        
        if currentCellVerified {
            print("⚠️ 当前格子已验证，请说「继续」")
            return
        }
        
        let correctDirection = trainingDirections[currentVerifyingIndex]
        print("✓ 正确答案: \(correctDirection.name)")
        
        if direction == correctDirection {
            print("✅ 答案正确！")
            currentCellVerified = true
            lastAnswerWasWrong = false
            cardView.setStatus(.correctWaitingSeparator, forIndex: currentVerifyingIndex)
            let prompt = "说「继续」进入下一题"
            showToast(message: "✅ 正确！\(prompt)", isSuccess: true)
            updateTrainingStateUI()
            if autoAdvance {
                moveToNextCell()
            } else {
                print("⏸️ 等待分隔词（继续）...")
            }
        } else {
            print("❌ 答案错误！")
            lastAnswerWasWrong = true
            showToast(message: "❌ 错误，请重试", isSuccess: false)
            updateTrainingStateUI()
            if isVoiceRecognitionEnabled {
                VoiceCommandRecognizer.shared.allowDirectionAgain()
            }
        }
    }
    
    private func moveToNextCell() {
        guard currentVerifyingIndex >= 0 else {
            print("⚠️ 没有正在验证的格子")
            return
        }
        
        guard currentCellVerified else {
            print("⚠️ 当前格子未验证，忽略「继续」指令")
            return
        }
        
        cardView.setStatus(.verified, forIndex: currentVerifyingIndex)
        currentCellVerified = false
        lastAnswerWasWrong = false

        if isVoiceRecognitionEnabled {
            VoiceCommandRecognizer.shared.clearForNextInput()
        }

        let nextIndex = currentVerifyingIndex + 1
        if nextIndex >= totalCount {
            print("🎉 全部完成！")
            currentVerifyingIndex = -1
            print("🎉 训练完成！")
            startButton.isEnabled = true
            startButton.alpha = 1.0
            startButton.setTitle("重新开始", for: .normal)
        } else {
            print("➡️ 移动到下一格: \(nextIndex + 1)")
            currentVerifyingIndex = nextIndex
            cardView.setStatus(.verifying, forIndex: nextIndex)
        }
        currentTranscript = ""
        updateTrainingStateUI()
    }
    
    /// 根据 trainingState 更新状态横幅：明显颜色 + 文案
    private func updateTrainingStateUI() {
        if let state = trainingState {
            stateBannerContainer.isHidden = false
            switch state {
            case .waitingDirection:
                stateBannerContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
                stateBannerLabel.textColor = .systemBlue
                stateBannerLabel.text = "请输出：上、下、左、右"
            case .recognizing(let transcript):
                stateBannerContainer.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.25)
                stateBannerLabel.textColor = .systemOrange
                let short = transcript.count > 20 ? String(transcript.prefix(18)) + "…" : transcript
                stateBannerLabel.text = "正在识别…\n「\(short)」"
            case .answeredCorrectWaitingContinue:
                stateBannerContainer.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.25)
                stateBannerLabel.textColor = .systemGreen
                stateBannerLabel.text = "✓ 正确\n请说「继续」"
            case .answeredWrong:
                stateBannerContainer.backgroundColor = UIColor.systemRed.withAlphaComponent(0.25)
                stateBannerLabel.textColor = .systemRed
                stateBannerLabel.text = "✗ 错误\n请重说方向"
            }
        } else {
            if !isVoiceRecognitionEnabled {
                stateBannerContainer.isHidden = true
                return
            }
            stateBannerContainer.isHidden = false
            stateBannerContainer.backgroundColor = UIColor.systemGray5
            stateBannerLabel.textColor = .secondaryLabel
            stateBannerLabel.text = "本组已完成，点击「重新开始」"
        }
    }

    private func updateRecognitionStatus(_ isRecognizing: Bool) {
        if isRecognizing {
            voiceStatusLabel.text = "准备就绪，可以说话"
            voiceStatusLabel.textColor = .systemGreen
            readyIndicator.backgroundColor = .systemGreen
            
            // 添加呼吸灯动画
            UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: {
                self.readyIndicator.alpha = 0.3
            })
        } else {
            voiceStatusLabel.text = "未就绪"
            voiceStatusLabel.textColor = .secondaryLabel
            readyIndicator.backgroundColor = .systemGray
            readyIndicator.layer.removeAllAnimations()
            readyIndicator.alpha = 1.0
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func showToast(message: String, isSuccess: Bool) {
        // 创建 Toast 容器视图（占屏幕高度的 1/5）
        let toastContainer = UIView()
        toastContainer.backgroundColor = (isSuccess ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.95)
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建文字标签
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.font = .systemFont(ofSize: 32, weight: .bold)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.numberOfLines = 0
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        toastContainer.addSubview(toastLabel)
        view.addSubview(toastContainer)
        
        // Toast 占屏幕高度的 1/5，宽度全屏，置于最顶层
        NSLayoutConstraint.activate([
            toastContainer.topAnchor.constraint(equalTo: view.topAnchor),
            toastContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toastContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toastContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.2),
            
            toastLabel.centerXAnchor.constraint(equalTo: toastContainer.centerXAnchor),
            toastLabel.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
            toastLabel.leadingAnchor.constraint(greaterThanOrEqualTo: toastContainer.leadingAnchor, constant: 40),
            toastLabel.trailingAnchor.constraint(lessThanOrEqualTo: toastContainer.trailingAnchor, constant: -40)
        ])
        
        // 确保在最顶层
        view.bringSubviewToFront(toastContainer)
        
        toastContainer.alpha = 0
        
        // 动画显示
        UIView.animate(withDuration: 0.3, animations: {
            toastContainer.alpha = 1.0
        }) { _ in
            // 2 秒后淡出
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                toastContainer.alpha = 0
            }) { _ in
                toastContainer.removeFromSuperview()
            }
        }
    }
    
    @objc private func voiceDebugTapped() {
        let debugVC = VoiceCommandDebugViewController()
        debugVC.modalPresentationStyle = .fullScreen
        present(debugVC, animated: true)
    }

    /// 刷新：打乱训练卡 E 方向
    @objc private func refreshTapped() {
        trainingDirections = VisionCardImage.directions.shuffled()
        cardView.directions = trainingDirections
        showToast(message: "刷新成功", isSuccess: true)
    }

    @objc private func backTapped() {
        if isVoiceRecognitionEnabled {
            VoiceCommandRecognizer.shared.stop()
        }
        dismiss(animated: true)
    }
    
    deinit {
        if isVoiceRecognitionEnabled {
            VoiceCommandRecognizer.shared.stop()
        }
    }
}

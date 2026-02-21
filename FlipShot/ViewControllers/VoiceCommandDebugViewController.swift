//
//  VoiceCommandDebugViewController.swift
//  FlipShot
//
//  VoiceCommandRecognizer 调试页：权限、启停、状态、识别原文、日志、命中命令
//

import UIKit
import AVFoundation

final class VoiceCommandDebugViewController: UIViewController {

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.showsVerticalScrollIndicator = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 12
        s.alignment = .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("关闭", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "VoiceCommandRecognizer 调试"
        l.font = .systemFont(ofSize: 20, weight: .bold)
        l.textAlignment = .center
        return l
    }()

    private let permissionLabel: UILabel = {
        let l = UILabel()
        l.text = "权限: —"
        l.font = .systemFont(ofSize: 14)
        l.numberOfLines = 0
        return l
    }()

    private let startStopButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("开始识别", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        b.backgroundColor = .systemGreen
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 10
        return b
    }()

    private let stateLabel: UILabel = {
        let l = UILabel()
        l.text = "状态: 未开始"
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.numberOfLines = 0
        return l
    }()

    /// 醒目状态横幅：只看这里就知道该说「方向」还是「继续」
    private let cueBannerContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 12
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let cueBannerLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.textAlignment = .center
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let transcriptTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "识别原文"
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        return l
    }()

    private let transcriptLabel: UILabel = {
        let l = UILabel()
        l.text = " "
        l.font = .systemFont(ofSize: 14)
        l.numberOfLines = 3
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let commandTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "最近命中"
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        return l
    }()

    private let commandLabel: UILabel = {
        let l = UILabel()
        l.text = "—"
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .systemBlue
        return l
    }()

    private let logTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "日志"
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        return l
    }()

    private let logTextView: UITextView = {
        let t = UITextView()
        t.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        t.isEditable = false
        t.backgroundColor = UIColor.systemGray6
        t.layer.cornerRadius = 8
        t.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return t
    }()

    private var logLines: [String] = []
    private let maxLogLines = 80
    /// 识别原文有内容但尚未命中时为 true，用于横幅显示「请等待」
    private var isProcessingVoice = false
    private var lastCue: VoiceCommandRecognizer.CueState = .idle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Voice 调试"

        view.addSubview(closeButton)
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(permissionLabel)
        stack.addArrangedSubview(startStopButton)
        stack.addArrangedSubview(stateLabel)
        cueBannerContainer.addSubview(cueBannerLabel)
        stack.addArrangedSubview(cueBannerContainer)
        NSLayoutConstraint.activate([
            cueBannerLabel.topAnchor.constraint(equalTo: cueBannerContainer.topAnchor, constant: 16),
            cueBannerLabel.leadingAnchor.constraint(equalTo: cueBannerContainer.leadingAnchor, constant: 20),
            cueBannerLabel.trailingAnchor.constraint(equalTo: cueBannerContainer.trailingAnchor, constant: -20),
            cueBannerLabel.bottomAnchor.constraint(equalTo: cueBannerContainer.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(transcriptTitleLabel)
        stack.addArrangedSubview(transcriptLabel)
        stack.addArrangedSubview(commandTitleLabel)
        stack.addArrangedSubview(commandLabel)
        stack.addArrangedSubview(logTitleLabel)
        stack.addArrangedSubview(logTextView)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
            logTextView.heightAnchor.constraint(equalToConstant: 200),
        ])

        startStopButton.addTarget(self, action: #selector(startStopTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        setupRecognizer()
        VoiceCommandRecognizer.shared.requestPermissions()
        updateStartStopButton()
        lastCue = .idle
        updateCueBanner()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateStartStopButton()
    }

    private func updateStartStopButton() {
        if VoiceCommandRecognizer.shared.isRecognizing {
            startStopButton.setTitle("停止识别", for: .normal)
            startStopButton.backgroundColor = .systemRed
        } else {
            startStopButton.setTitle("开始识别", for: .normal)
            startStopButton.backgroundColor = .systemGreen
        }
    }

    private func setupRecognizer() {
        let r = VoiceCommandRecognizer.shared
        r.onPermissionChanged = { [weak self] mic, speech in
            DispatchQueue.main.async {
                self?.permissionLabel.text = "麦克风: \(mic ? "✅" : "❌")  语音: \(speech ? "✅" : "❌")"
            }
        }
        r.onTranscript = { [weak self] text, isFinal in
            DispatchQueue.main.async {
                self?.transcriptLabel.text = text.isEmpty ? " " : (isFinal ? "「\(text)」 (final)" : "「\(text)」")
            }
        }
        r.onProcessing = { [weak self] processing in
            DispatchQueue.main.async {
                self?.isProcessingVoice = processing
                self?.updateCueBanner()
            }
        }
        r.onCueStateChanged = { [weak self] cue in
            DispatchQueue.main.async {
                self?.lastCue = cue
                self?.updateStateLabel(cue)
                self?.updateCueBanner()
            }
        }
        r.onCommand = { [weak self] cmd in
            DispatchQueue.main.async {
                self?.commandLabel.text = cmd.display
                self?.commandLabel.textColor = cmd.isDirection ? .systemBlue : .systemOrange
            }
        }
        r.onLog = { [weak self] line in
            DispatchQueue.main.async {
                self?.appendLog(line)
            }
        }
        r.onErrorText = { [weak self] msg in
            DispatchQueue.main.async {
                self?.appendLog("❌ \(msg)")
            }
        }
    }

    private func updateStateLabel(_ cue: VoiceCommandRecognizer.CueState) {
        switch cue {
        case .idle:
            stateLabel.text = "状态: 未识别"
        case .cooldown(let remaining):
            stateLabel.text = "状态: 冷却 \(String(format: "%.1f", remaining))s"
        case .awaitingDirection:
            stateLabel.text = "状态: 等待方向词（上/下/左/右）"
        case .awaitingSeparator:
            stateLabel.text = "状态: 等待分隔词（继续）"
        }
    }

    /// 醒目横幅：不看识别原文/最近命中，一眼知道该说方向、继续，或请等待
    private func updateCueBanner() {
        if VoiceCommandRecognizer.shared.isRecognizing && isProcessingVoice {
            cueBannerContainer.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.3)
            cueBannerLabel.textColor = .systemOrange
            cueBannerLabel.text = "识别原文已有内容，尚未命中\n请等待"
            return
        }
        switch lastCue {
        case .idle:
            cueBannerContainer.backgroundColor = UIColor.systemGray5
            cueBannerLabel.textColor = .secondaryLabel
            cueBannerLabel.text = "未开始\n点击「开始识别」"
        case .cooldown(let remaining):
            cueBannerContainer.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.2)
            cueBannerLabel.textColor = .systemOrange
            cueBannerLabel.text = "冷却 \(String(format: "%.1f", remaining)) 秒\n然后说方向"
        case .awaitingDirection:
            cueBannerContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.25)
            cueBannerLabel.textColor = .systemBlue
            cueBannerLabel.text = "请说方向\n上 / 下 / 左 / 右"
        case .awaitingSeparator:
            cueBannerContainer.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.25)
            cueBannerLabel.textColor = .systemGreen
            cueBannerLabel.text = "请说「继续」"
        }
    }

    private func appendLog(_ line: String) {
        logLines.append(line)
        if logLines.count > maxLogLines {
            logLines.removeFirst(logLines.count - maxLogLines)
        }
        logTextView.text = logLines.joined(separator: "\n")
        let len = logTextView.text.count
        if len > 0 {
            logTextView.scrollRangeToVisible(NSRange(location: len - 1, length: 1))
        }
    }

    @objc private func startStopTapped() {
        let r = VoiceCommandRecognizer.shared
        if r.isRecognizing {
            r.stop()
            stateLabel.text = "状态: 已停止"
            lastCue = .idle
            isProcessingVoice = false
            updateCueBanner()
        } else {
            r.start()
        }
        updateStartStopButton()
    }

    @objc private func closeTapped() {
        VoiceCommandRecognizer.shared.stop()
        dismiss(animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        VoiceCommandRecognizer.shared.stop()
    }
}

import AVFoundation
import Foundation
import Speech

final class VoiceCommandRecognizer: NSObject {

    // MARK: - Types

    enum Command: String {
        case up, down, left, right
        case `continue`, next

        var display: String {
            switch self {
            case .up: return "上"
            case .down: return "下"
            case .left: return "左"
            case .right: return "右"
            case .continue: return "继续"
            case .next: return "下一个"
            }
        }

        var isDirection: Bool {
            switch self {
            case .up, .down, .left, .right: return true
            case .continue, .next: return false
            }
        }

        var isSeparator: Bool {
            switch self {
            case .continue, .next: return true
            case .up, .down, .left, .right: return false
            }
        }
    }

    enum Phase {
        case direction
        case separator
    }

    enum CueState {
        case idle
        case cooldown(remaining: TimeInterval)
        case awaitingDirection
        case awaitingSeparator
    }

    struct Config {
        var locale = Locale(identifier: "zh-CN")

        /// 方向词触发后，多久才允许下一次方向词（在 separator 解锁后生效）
        var cooldownSeconds: TimeInterval = 0.8

        /// 静默这么久（无新 partial 更新）就把最后一次 partial 当 final 匹配；匀速说话时若识别器更新有间隔，建议 ≥2s 减少误触发
        var silenceAutoFinalSeconds: TimeInterval = 1.2

        /// 日志去重（同一文本短时间重复不刷屏）
        var logDedupSeconds: TimeInterval = 0.8

        /// 只在文本很短时才做方向词即时匹配，避免“上一个/左边”那种长句乱触发
        /// 但你又需要支持“左边”，所以我们用拼音前缀匹配，并允许短语
        var maxImmediateCharsForDirection: Int = 6
    }

    // MARK: - Callbacks

    var onLog: ((String) -> Void)?
    var onTranscript: ((String, Bool) -> Void)?
    var onCueStateChanged: ((CueState) -> Void)?
    var onCommand: ((Command) -> Void)?              // 方向词 & 分隔词都会回调
    var onDirectionCommand: ((Command) -> Void)?     // 仅方向词
    /// true = 识别原文已有、正在算本句答案；false = 处理完。用于 UI 显示「正在处理中」避免用户以为没听见
    var onProcessing: ((Bool) -> Void)?
    var onErrorText: ((String) -> Void)?
    var onPermissionChanged: ((Bool, Bool) -> Void)?

    // MARK: - State

    private let config: Config
    private let speechRecognizer: SFSpeechRecognizer?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var phase: Phase = .direction
    private(set) var isRecognizing = false

    private var hasMicAuth = false
    private var hasSpeechAuth = false
    private var hasMicResultReceived = false
    private var hasSpeechResultReceived = false

    private var cueTimer: Timer?
    private var silenceTimer: Timer?
    private var lastPartialTextForTimeout: String?
    /// 上次已提交的识别原文（tryMatch 用过的），用于与当前原文 diff，及时更新「正在处理中」
    private var lastCommittedTranscript = ""

    private var directionCooldownUntil = Date.distantPast

    private var lastLoggedText = ""
    private var lastLoggedAt = Date.distantPast

    private lazy var logFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static let shared = VoiceCommandRecognizer()

    init(config: Config = .init()) {
        self.config = config
        self.speechRecognizer = SFSpeechRecognizer(locale: config.locale)
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Permissions

    func requestPermissions() {
        hasMicResultReceived = false
        hasSpeechResultReceived = false

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hasMicAuth = granted
                self.hasMicResultReceived = true
                self.firePermissionChangedIfReady()
            }
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hasSpeechAuth = (status == .authorized)
                self.hasSpeechResultReceived = true
                self.firePermissionChangedIfReady()
            }
        }
    }

    private func firePermissionChangedIfReady() {
        guard hasMicResultReceived && hasSpeechResultReceived else { return }
        onPermissionChanged?(hasMicAuth, hasSpeechAuth)
    }

    // MARK: - Public Controls

    func start() {
        guard hasMicAuth && hasSpeechAuth else {
            onErrorText?("缺少权限(麦克风或语音识别)")
            return
        }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            onErrorText?("语音识别当前不可用")
            return
        }

        // 统一音频会话（建议 measurement，尽量减少系统处理带来的不确定性）
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onErrorText?("音频会话失败: \(error.localizedDescription)")
            return
        }

        isRecognizing = true
        phase = .direction
        directionCooldownUntil = Date() // 允许立即说方向
        emitLog("开始识别（两阶段：Direction → Separator）")

        startCueTimer()
        startRecognitionPipeline(for: .direction)
        emitCue()
    }

    func stop() {
        stopRecognitionPipeline()
        isRecognizing = false
        stopCueTimer()
        cancelSilenceTimer()
        lastPartialTextForTimeout = nil
        phase = .direction
        directionCooldownUntil = .distantPast
        emitCue()
        emitLog("停止识别")
    }

    /// 下一题：清空状态，允许立即方向词
    func clearForNextInput() {
        phase = .direction
        directionCooldownUntil = Date()
        cancelSilenceTimer()
        lastPartialTextForTimeout = nil
        emitCue()
    }

    /// 答错后：允许立即再说方向词
    func allowDirectionAgain() {
        phase = .direction
        directionCooldownUntil = Date()
        cancelSilenceTimer()
        lastPartialTextForTimeout = nil
        // 重启方向阶段，彻底清空旧转写（避免“识别过的”残留）
        if isRecognizing {
            startRecognitionPipeline(for: .direction)
        }
        emitCue()
    }

    // MARK: - Pipeline

    private func startRecognitionPipeline(for newPhase: Phase) {
        phase = newPhase
        cancelSilenceTimer()
        lastPartialTextForTimeout = nil

        // 仅重启时清理上一轮 request/task/tap，首次启动不碰
        if recognitionRequest != nil || recognitionTask != nil {
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true   // 要 partial，静默超时才能当 final
        request.requiresOnDeviceRecognition = true  // 本机识别，隐私且可离线

        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0,
                             bufferSize: 1024,
                             format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        if !audioEngine.isRunning {
            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                onErrorText?("启动录音失败: \(error.localizedDescription)")
                return
            }
        }

        emitLog("进入阶段：\(newPhase == .direction ? "等待方向词" : "等待分隔词")")

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let result {
                    let text = result.bestTranscription.formattedString
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isDuplicate = !trimmed.isEmpty && trimmed == self.lastCommittedTranscript

                    if !trimmed.isEmpty && !isDuplicate {
                        self.onProcessing?(true)
                    }
                    if isDuplicate {
                        self.onTranscript?("", false)
                    } else {
                        self.onTranscript?(text, result.isFinal)
                    }

                    if result.isFinal {
                        self.emitLog("识别(final): \(text)")
                        if !isDuplicate {
                            self.tryMatch(text: text, isFinal: true)
                        } else {
                            self.emitLog("跳过重复 final，已提交过: \(text)")
                        }
                    } else {
                        self.emitLog("识别(partial): \(text) → 若 \(self.config.silenceAutoFinalSeconds)s 内无新结果将当 final")
                    }

                    self.lastPartialTextForTimeout = text
                    if !isDuplicate {
                        self.scheduleSilenceTimer()
                    }
                }

                if let error {
                    self.emitLog("识别报错: \(error.localizedDescription)")
                    guard self.isRecognizing else {
                        self.stop()
                        return
                    }
                    // No speech detected 时立即重启会死循环，延迟 1 秒再重启，方便用户说「继续」
                    let isNoSpeech = error.localizedDescription.contains("No speech detected") || error.localizedDescription.contains("no speech")
                    if isNoSpeech {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            guard let self, self.isRecognizing else { return }
                            self.emitLog("No speech 后延迟重启")
                            self.startRecognitionPipeline(for: self.phase)
                            self.emitCue()
                        }
                    } else {
                        self.startRecognitionPipeline(for: self.phase)
                        self.emitCue()
                    }
                }
            }
        }
    }

    private func stopRecognitionPipeline() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Matching

    /// 仅用于单元测试：将阶段重置为“等待方向词”并对文本执行一次 final 匹配（不经过语音引擎）
    func processTextForTest(_ text: String) {
        phase = .direction
        directionCooldownUntil = Date.distantPast
        tryMatch(text: text, isFinal: true)
    }

    private func tryMatch(text: String, isFinal: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isFinal {
            onProcessing?(true)
            defer { onProcessing?(false) }
        }
        emitLogDedup("识别(\(isFinal ? "final" : "partial")): \(trimmed)")

        let pinyin = toPinyin(trimmed)
        var remaining = pinyin
        let maxRounds = 30
        var rounds = 0
        var lastMatchedCommand: Command?
        var lastDirectionInSentence: Command?  // 本句最后一个方向 = 答案，只回调一次

        while rounds < maxRounds {
            rounds += 1
            let s = normalize(remaining)

            let dirMatch = matchDirection(normalized: s)
            let sepMatch = matchSeparatorWithRange(normalized: s)

            let chosen: (Command, Range<String.Index>)?
            switch (dirMatch, sepMatch) {
            case let (d?, s?):
                chosen = d.2.lowerBound <= s.2.lowerBound ? (d.0, d.2) : (s.0, s.2)
            case let (d?, _):
                chosen = (d.0, d.2)
            case let (_, s?):
                chosen = (s.0, s.2)
            case (nil, nil):
                chosen = nil
            }

            guard let (c, r) = chosen else { break }
            if c.isDirection, isRecognizing, Date() < directionCooldownUntil { break }

            emitCommand(c)
            lastMatchedCommand = c
            if c.isDirection { lastDirectionInSentence = c }
            remaining = String(s[..<r.lowerBound]) + String(s[r.upperBound...])
            if remaining.isEmpty { break }
        }
        if let lastDir = lastDirectionInSentence {
            onDirectionCommand?(lastDir)
            emitLog("本句答案(最后方向): \(lastDir.display)")
        }
        if let last = lastMatchedCommand {
            emitLog("本句最后命中: \(last.display)，下一阶段: \(last.isDirection ? "等待分隔词" : "等待方向词")")
            applyPhaseAfterMatch(last)
        }
        lastCommittedTranscript = trimmed
    }

    /// 从拼音串中移除首次出现的匹配子串（用于分隔词消耗）
    private func consumeMatch(from pinyin: String, matched: String) -> String {
        let s = normalize(pinyin)
        guard let r = s.range(of: matched) else { return pinyin }
        return String(s[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 静默到点，把最后一次 partial 当 final 再触发一次（防止系统迟迟不给 final）
    private func fireSilenceAutoFinal() {
        cancelSilenceTimer()
        guard isRecognizing else { return }
        guard let text = lastPartialTextForTimeout?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        emitLog("静默 \(config.silenceAutoFinalSeconds)s，按 final 处理: \(text)")
        tryMatch(text: text, isFinal: true)
    }

    /// 只做 onCommand 与日志；方向词不在此处回调 onDirectionCommand，句末统一回调本句最后方向一次
    private func emitCommand(_ command: Command) {
        if command.isDirection {
            emitLog("命中方向词: \(command.display)")
            onCommand?(command)
        } else {
            emitLog("命中分隔词: \(command.display)（解锁下一次方向词）")
            onCommand?(command)
        }
    }

    /// 根据本句最后命中的 token 更新 phase 与冷却（仅句末执行一次）
    private func applyPhaseAfterMatch(_ command: Command) {
        cancelSilenceTimer()
        lastPartialTextForTimeout = nil
        if command.isDirection {
            phase = .separator
            emitLog("进入阶段：等待分隔词（下一句需说 继续）")
            emitCue()
        } else {
            if isRecognizing {
                directionCooldownUntil = Date().addingTimeInterval(config.cooldownSeconds)
            }
            phase = .direction
            emitLog("进入阶段：等待方向词（不重启管道）")
            emitCue()
        }
    }

    private func handleCommand(_ command: Command) {
        emitCommand(command)
        applyPhaseAfterMatch(command)
    }

    // MARK: - Match Rules (Pinyin)

    /// 方向：按出现顺序取第一个方向词（规则表要求方向序列为顺序）。返回 (命令, 匹配前缀, 在归一化串中的范围)。
    private func matchDirection(normalized s: String) -> (Command, String, Range<String.Index>)? {
        guard !s.isEmpty else { return nil }

        let groups: [(Command, [String])] = [
            (.up, ["shang", "sha", "sang", "xiang"]),  // 向 → 上
            (.down, ["xia", "hia"]),  // 不用 "xi"，避免「向」xiang 误命中
            (.left, ["zuo", "zu", "zhuo"]),
            (.right, ["you", "yo", "iu"])
        ]
        var firstMatch: (range: Range<String.Index>, command: Command, prefix: String)?
        for (cmd, prefixes) in groups {
            for p in prefixes {
                let r: Range<String.Index>?
                if p == "xia" {
                    var start = s.startIndex
                    var found: Range<String.Index>?
                    while let rr = s.range(of: "xia", range: start..<s.endIndex) {
                        if !s[rr.lowerBound...].hasPrefix("xiang") {
                            found = rr
                            break
                        }
                        start = rr.upperBound
                    }
                    r = found
                } else {
                    r = s.range(of: p)
                }
                guard let r = r else { continue }
                if let e = firstMatch {
                    if r.lowerBound < e.range.lowerBound { firstMatch = (r, cmd, p) }
                } else {
                    firstMatch = (r, cmd, p)
                }
            }
        }
        guard let first = firstMatch else { return nil }
        return (first.command, first.prefix, first.range)
    }

    /// 分隔词：仅 继续（不匹配「下一个」，避免与「下」冲突）。返回 (命令, 首次匹配子串, 范围) 便于与方向比谁更靠前。
    private func matchSeparatorWithRange(normalized s: String) -> (Command, String, Range<String.Index>)? {
        guard !s.isEmpty else { return nil }

        let groups: [(Command, [String])] = [
            (.continue, ["jixu", "jixuyixia", "jixuba", "jixv", "jixü", "continue"])
        ]
        var earliest: (range: Range<String.Index>, command: Command, part: String)?
        for (cmd, parts) in groups {
            for p in parts {
                guard let r = s.range(of: p) else { continue }
                if let e = earliest {
                    if r.lowerBound < e.range.lowerBound { earliest = (r, cmd, p) }
                } else {
                    earliest = (r, cmd, p)
                }
            }
        }
        guard let e = earliest else { return nil }
        return (e.command, e.part, e.range)
    }

    private func firstPrefix(_ s: String, _ prefixes: [String]) -> String? {
        for p in prefixes where s.hasPrefix(p) { return p }
        return nil
    }

    private func firstContained(_ s: String, _ parts: [String]) -> String? {
        var earliest: (range: Range<String.Index>, part: String)?
        for p in parts {
            guard let r = s.range(of: p) else { continue }
            if let e = earliest {
                if r.lowerBound < e.range.lowerBound { earliest = (r, p) }
            } else {
                earliest = (r, p)
            }
        }
        return earliest?.part
    }

    private func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    // MARK: - Pinyin

    /// 将中文转拼音；如果原本就是拼音/ASCII，则直接归一化返回
    private func toPinyin(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // 仅当整句都是 ASCII（如 next / zuo）时直接归一化，否则转拼音（含「上x」「x上」等混排）
        let asciiCount = trimmed.unicodeScalars.filter { $0.isASCII }.count
        if asciiCount == trimmed.unicodeScalars.count {
            return normalize(trimmed)
        }

        let lower = trimmed.lowercased()
        let filtered = lower.filter { !$0.isWhitespace && !$0.isPunctuation }
        let mutable = NSMutableString(string: filtered) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (mutable as String).replacingOccurrences(of: " ", with: "")
    }

    // MARK: - Cue / Timers

    private func emitCue() {
        guard isRecognizing else {
            onCueStateChanged?(.idle)
            return
        }

        if phase == .direction, Date() < directionCooldownUntil {
            onCueStateChanged?(.cooldown(remaining: max(directionCooldownUntil.timeIntervalSinceNow, 0)))
            return
        }

        switch phase {
        case .direction:
            onCueStateChanged?(.awaitingDirection)
        case .separator:
            onCueStateChanged?(.awaitingSeparator)
        }
    }

    private func startCueTimer() {
        stopCueTimer()
        cueTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.emitCue()
        }
        RunLoop.main.add(cueTimer!, forMode: .common)
    }

    private func stopCueTimer() {
        cueTimer?.invalidate()
        cueTimer = nil
    }

    private func scheduleSilenceTimer() {
        cancelSilenceTimer()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: config.silenceAutoFinalSeconds, repeats: false) { [weak self] _ in
            self?.fireSilenceAutoFinal()
        }
        RunLoop.main.add(silenceTimer!, forMode: .common)
    }

    private func cancelSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    // MARK: - Logging

    private func emitLog(_ message: String) {
        let line = "[\(logFormatter.string(from: Date()))] \(message)"
        print("🎤 \(line)")
        onLog?(line)
    }

    private func emitLogDedup(_ message: String) {
        let now = Date()
        if message == lastLoggedText, now.timeIntervalSince(lastLoggedAt) < config.logDedupSeconds {
            return
        }
        lastLoggedText = message
        lastLoggedAt = now
        emitLog(message)
    }
}

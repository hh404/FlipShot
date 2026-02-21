//
//  SpeechRecognitionManager.swift
//  FlipShot
//
//  语音识别管理器：识别"上/下/左/右"方向指令
//

import Speech
import AVFoundation

final class SpeechRecognitionManager: NSObject {
    
    static let shared = SpeechRecognitionManager()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    /// 识别到方向的回调
    var onDirectionRecognized: ((EDirection) -> Void)?
    
    /// 识别到"下一个"指令的回调
    var onNextCommand: (() -> Void)?
    
    /// 识别状态变化回调
    var onStatusChanged: ((Bool) -> Void)?  // true = 正在识别, false = 已停止
    
    /// 上次识别到的方向（用于防止重复触发）
    private var lastRecognizedDirection: EDirection?
    private var lastRecognizedTime: Date?
    
    /// 上次识别到"下一个"指令的时间（用于防止重复触发）
    private var lastNextCommandTime: Date?
    
    /// 上次处理的文本长度（用于只处理新增部分）
    private var lastProcessedLength: Int = 0
    
    /// 连续"无语音"错误计数
    private var consecutiveNoSpeechErrors: Int = 0
    private let maxConsecutiveErrors = 3
    
    private override init() {
        super.init()
    }
    
    /// 请求语音识别权限
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    completion(true)
                case .denied, .restricted, .notDetermined:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    /// 开始语音识别
    func startRecognition() throws {
        print("🎤 开始语音识别...")
        
        // 检测是否在模拟器上运行
        #if targetEnvironment(simulator)
        print("⚠️ 检测到模拟器环境，语音识别可能不稳定")
        print("⚠️ 建议使用真机测试语音功能")
        // 模拟器环境下，仍然尝试启动，但如果失败不抛出错误
        #endif
        
        // 先完全清理音频引擎
        if audioEngine.isRunning {
            print("⚠️ 音频引擎已在运行，先停止")
            audioEngine.stop()
        }
        
        // 移除所有已存在的 tap（忽略错误）
        let inputNode = audioEngine.inputNode
        do {
            inputNode.removeTap(onBus: 0)
            print("🧹 移除旧的 tap")
        } catch {
            print("⚠️ 移除 tap 时出错（可能不存在）: \(error.localizedDescription)")
        }
        
        // 取消旧的识别任务
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // 检查权限
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        print("🔐 语音识别权限状态: \(authStatus.rawValue)")
        guard authStatus == .authorized else {
            throw NSError(domain: "SpeechRecognition", code: 1, userInfo: [NSLocalizedDescriptionKey: "语音识别未授权"])
        }
        
        // 检查识别器是否可用
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("❌ 语音识别器不可用")
            throw NSError(domain: "SpeechRecognition", code: 3, userInfo: [NSLocalizedDescriptionKey: "语音识别器不可用"])
        }
        print("✅ 语音识别器可用")
        
        // 配置音频会话（允许播放和录音同时进行）
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ 音频会话配置成功")
            
            // 检查麦克风权限
            switch audioSession.recordPermission {
            case .granted:
                print("✅ 麦克风权限已授予")
            case .denied:
                print("❌ 麦克风权限被拒绝")
                throw NSError(domain: "SpeechRecognition", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "麦克风权限被拒绝，请在设置中允许"
                ])
            case .undetermined:
                print("⚠️ 麦克风权限未确定，正在请求...")
                // 权限会在第一次使用时自动请求
            @unknown default:
                print("⚠️ 未知的麦克风权限状态")
            }
        } catch {
            print("❌ 音频会话配置失败: \(error.localizedDescription)")
            throw error
        }
        
        // 先启动音频引擎（确保输入节点格式有效）
        do {
            audioEngine.prepare()
            print("⏳ 音频引擎准备中...")
            
            // 设置超时保护（模拟器可能卡死）
            var engineStarted = false
            let startGroup = DispatchGroup()
            startGroup.enter()
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.audioEngine.start()
                    engineStarted = true
                    print("✅ 音频引擎已启动")
                } catch {
                    print("❌ 音频引擎启动失败: \(error.localizedDescription)")
                }
                startGroup.leave()
            }
            
            // 等待最多 3 秒
            let timeout = startGroup.wait(timeout: .now() + 3.0)
            
            if timeout == .timedOut {
                print("❌ 音频引擎启动超时（可能是模拟器问题）")
                #if targetEnvironment(simulator)
                print("💡 请在真机上测试语音识别功能")
                throw NSError(domain: "SpeechRecognition", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "模拟器不支持语音识别，请使用真机测试"
                ])
                #else
                throw NSError(domain: "SpeechRecognition", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "音频引擎启动超时"
                ])
                #endif
            }
            
            guard engineStarted else {
                throw NSError(domain: "SpeechRecognition", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "音频引擎启动失败"
                ])
            }
        } catch {
            print("❌ 启动音频引擎时出错: \(error.localizedDescription)")
            throw error
        }
        
        // 获取音频输入格式（必须在引擎启动后）
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 验证音频格式
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("❌ 音频格式无效: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)")
            audioEngine.stop()
            throw NSError(domain: "SpeechRecognition", code: 4, userInfo: [NSLocalizedDescriptionKey: "音频格式无效"])
        }
        
        print("✅ 音频格式: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)")
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            audioEngine.stop()
            throw NSError(domain: "SpeechRecognition", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法创建识别请求"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 安装音频 tap
        do {
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            print("✅ Tap 安装成功")
        } catch {
            print("❌ 安装 tap 失败: \(error.localizedDescription)")
            audioEngine.stop()
            throw error
        }
        
        // 开始识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var shouldStop = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                
                // 只处理新增的部分（避免重复处理累积文本）
                let currentLength = transcription.count
                // 成功识别到语音，重置错误计数
                self.consecutiveNoSpeechErrors = 0
                
                if currentLength > self.lastProcessedLength {
                    let startIndex = transcription.index(transcription.startIndex, offsetBy: self.lastProcessedLength)
                    let newText = String(transcription[startIndex...])
                    print("🎤 识别: \(newText)")
                    self.processTranscription(newText)
                    self.lastProcessedLength = currentLength
                }
                
                // 检查是否是最终结果（静默重启，不打印日志）
                if result.isFinal {
                    shouldStop = true
                }
            }
            
            if let error = error {
                let errorMessage = error.localizedDescription
                print("❌ 语音识别错误: \(errorMessage)")
                
                // 检测 "No speech detected" 错误（仅记录，不停止）
                if errorMessage.contains("No speech detected") {
                    self.consecutiveNoSpeechErrors += 1
                    print("⚠️ 无语音输入 (\(self.consecutiveNoSpeechErrors) 次)，继续监听...")
                    // 不停止，继续重启识别任务
                } else {
                    // 其他错误，重置计数
                    self.consecutiveNoSpeechErrors = 0
                }
                
                shouldStop = true
            }
            
            // 如果识别任务结束，静默重启（不停止引擎）
            if shouldStop {
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.lastProcessedLength = 0
                
                // 延迟 0.2 秒后重启识别任务（引擎保持运行）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.restartRecognitionTask()
                }
            }
        }
        
        print("✅ 识别任务已启动")
        
        onStatusChanged?(true)
    }
    
    /// 停止语音识别
    func stopRecognition() {
        print("🛑 停止语音识别")
        
        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            print("✅ 音频引擎已停止")
        }
        
        // 移除 tap（忽略错误）
        do {
            audioEngine.inputNode.removeTap(onBus: 0)
            print("✅ Tap 已移除")
        } catch {
            print("⚠️ 移除 tap 时出错: \(error.localizedDescription)")
        }
        
        // 结束识别请求
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionTask = nil
        recognitionRequest = nil
        lastProcessedLength = 0
        onStatusChanged?(false)
    }
    
    /// 处理识别结果，使用拼音模糊匹配方向和"下一个"指令
    private func processTranscription(_ text: String) {
        // 将文本转换为拼音
        let pinyin = text.applyingTransform(.mandarinToLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false)?
            .lowercased() ?? ""
        
        print("🔤 拼音: \(pinyin)")
        
        // 优先检查"下一个"或"继续"指令（模糊匹配）
        // 匹配：xia yi ge, ji xu, xia yi, ji
        if pinyin.contains("xia yi") || pinyin.contains("ji xu") || pinyin.contains("jixu") ||
           (pinyin.contains("ji") && !pinyin.contains("shang") && !pinyin.contains("xia") && !pinyin.contains("zuo") && !pinyin.contains("you")) {
            
            // 防止重复触发：2秒内只触发一次"下一个"
            let now = Date()
            if let lastTime = lastNextCommandTime,
               now.timeIntervalSince(lastTime) < 2.0 {
                print("⏭️ 忽略重复的「下一个」指令")
                return
            }
            
            lastNextCommandTime = now
            print("➡️ 识别到指令: 下一个")
            onNextCommand?()
            return
        }
        
        // 模糊匹配方向拼音（只要包含 shang/xia/zuo/you 即可）
        // 优先级：shang > xia > zuo > you（避免 xia 误匹配到 "xia yi ge"）
        var recognizedDirection: EDirection?
        
        // 排除"下一个"中的 xia
        let pinyinWithoutNext = pinyin.replacingOccurrences(of: "xia yi", with: "")
        
        if pinyinWithoutNext.contains("shang") {
            recognizedDirection = .up
        } else if pinyinWithoutNext.contains("xia") {
            recognizedDirection = .down
        } else if pinyinWithoutNext.contains("zuo") {
            recognizedDirection = .left
        } else if pinyinWithoutNext.contains("you") || pinyinWithoutNext.contains("yo") {
            recognizedDirection = .right
        }
        
        if let direction = recognizedDirection {
            // 防止重复触发：如果1秒内识别到相同方向，忽略
            let now = Date()
            if let lastDir = lastRecognizedDirection,
               let lastTime = lastRecognizedTime,
               lastDir == direction,
               now.timeIntervalSince(lastTime) < 1.0 {
                print("⏭️ 忽略重复识别: \(direction.name)")
                return
            }
            
            lastRecognizedDirection = direction
            lastRecognizedTime = now
            
            print("✅ 识别到方向: \(direction.name) (拼音包含: \(direction == .up ? "shang" : direction == .down ? "xia" : direction == .left ? "zuo" : "you"))")
            onDirectionRecognized?(direction)
        } else {
            print("⚠️ 未匹配到方向关键词 - 原文: \(text), 拼音: \(pinyin)")
        }
    }
    
    /// 清除识别历史（切换到下一个格子时调用）
    /// 重启识别任务（不重启引擎，静默运行）
    private func restartRecognitionTask() {
        guard audioEngine.isRunning else {
            return
        }
        
        // 创建新的识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        // 开始新的识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var shouldStop = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                
                let currentLength = transcription.count
                self.consecutiveNoSpeechErrors = 0
                
                if currentLength > self.lastProcessedLength {
                    let startIndex = transcription.index(transcription.startIndex, offsetBy: self.lastProcessedLength)
                    let newText = String(transcription[startIndex...])
                    print("🎤 新增识别: \(newText) (完整: \(transcription))")
                    self.processTranscription(newText)
                    self.lastProcessedLength = currentLength
                }
                
                if result.isFinal {
                    shouldStop = true
                }
            }
            
            if let error = error {
                let errorMessage = error.localizedDescription
                
                // 只记录非"无语音"错误
                if !errorMessage.contains("No speech detected") {
                    print("❌ 语音识别错误: \(errorMessage)")
                }
                
                self.consecutiveNoSpeechErrors = 0
                shouldStop = true
            }
            
            if shouldStop {
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.lastProcessedLength = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.restartRecognitionTask()
                }
            }
        }
    }
    
    func clearRecognitionHistory() {
        lastRecognizedDirection = nil
        lastRecognizedTime = nil
        lastNextCommandTime = nil
        consecutiveNoSpeechErrors = 0
        
        // 不重启任务，只标记当前位置，忽略之前的所有文本
        print("🧹 清除识别历史（标记忽略旧文本）")
        // 注意：不重置为 0，而是保持当前长度，这样新文本才会被处理
    }
    
    
    /// 检查是否可用
    var isAvailable: Bool {
        return speechRecognizer?.isAvailable ?? false
    }
}

//
//  VoiceManager.swift
//  FlipShot
//
//  中文语音播报，孩子不用看字也能跟着做
//

import AVFoundation
import UIKit

final class VoiceManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VoiceManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    /// 播报完成的回调
    var onSpeechFinished: (() -> Void)?
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String, rate: Float = 0.45) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = rate
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - 固定话术（方便统一修改）
    
    func sayWelcome() {
        speak("翻转拍训练。点一下屏幕开始。")
    }
    
    func sayGetReady() {
        speak("把 iPad 放好，眼睛看着屏幕。准备好了就点一下屏幕。")
    }
    
    func sayCountdown(_ n: Int) {
        if n > 0 { speak("\(n)") }
    }
    
    func sayGo() {
        speak("开始！")
    }
    
    // MARK: - 视标相关语音
    
    func sayOptotypeE(direction: EDirection) {
        speak("看屏幕上的 E，是朝\(direction.name)边")
    }
    
    func sayOptotypeLetter(_ letter: String) {
        speak("看屏幕上的字母，是 \(letter)")
    }
    
    func sayLookAtVisionLine(_ visionLine: VisionLine) {
        speak("看屏幕上的视标，说出每个的方向")
    }
    
    func sayRest(seconds: Int) {
        speak("休息一下，\(seconds) 秒后继续。")
    }
    
    func sayRoundDone(current: Int, total: Int) {
        if current < total {
            speak("这一组完成啦！休息一下。")
        }
    }
    
    func sayAllDone() {
        speak("今天练完了，真棒！")
    }
    
    // MARK: - 训练反馈
    
    func sayCorrect() {
        speak("正确")
    }
    
    func sayWrong() {
        speak("错误")
    }
    
    func sayCellNumber(_ number: Int) {
        speak("第 \(number) 个")
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 语音播报完成")
        onSpeechFinished?()
    }
}

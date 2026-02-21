//
//  Untitled.swift
//  FlipShot
//
//  Created by hanshuang on 2026/2/21.
//

import AVFoundation
import Speech
import Foundation

final class VoiceDirectionRecognizerV2 {

    enum Direction {
        case up, down, left, right
    }

    var onDirection: ((Direction) -> Void)?
    var onError: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastProcessedLength = 0
    private var lastEmittedDirection: Direction?

    func start() {
        resetState()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request

        let input = audioEngine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0,
                         bufferSize: 1024,
                         format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.handle(text: text)
            }

            if let error {
                self.onError?(error.localizedDescription)
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
    }

    private func resetState() {
        lastProcessedLength = 0
        lastEmittedDirection = nil
    }

    private func handle(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Apple 有时会回退文本
        if trimmed.count < lastProcessedLength {
            lastProcessedLength = 0
        }

        let newPart = String(trimmed.dropFirst(lastProcessedLength))
        lastProcessedLength = trimmed.count

        let pinyin = toPinyin(newPart)

        if let direction = matchLastDirection(pinyin: pinyin) {
            if direction != lastEmittedDirection {
                lastEmittedDirection = direction
                onDirection?(direction)
            }
        }
    }

    // MARK: - Matching

    private func matchLastDirection(pinyin: String) -> Direction? {
        let s = pinyin.lowercased()

        var lastMatch: (Direction, String.Index)?

        let patterns: [(Direction, String)] = [
            (.up, "shang"),
            (.down, "xia"),
            (.left, "zuo"),
            (.right, "you")
        ]

        for (dir, key) in patterns {
            if let range = s.range(of: key, options: .backwards) {
                if lastMatch == nil || range.lowerBound > lastMatch!.1 {
                    lastMatch = (dir, range.lowerBound)
                }
            }
        }

        return lastMatch?.0
    }

    private func toPinyin(_ text: String) -> String {
        let mutable = NSMutableString(string: text) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (mutable as String)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}

//
//  VoiceCommandRecognizerTests.swift
//  FlipShotTests
//

import Testing
@testable import FlipShot

/// 规则表用例：输入文本 -> 本句答案(仅最后方向)，onDirectionCommand 每句只回调一次
struct VoiceCommandRecognizerTests {

    @Test func voiceCommand_ruleTable_allCases() async throws {
        var config = VoiceCommandRecognizer.Config()
        config.maxImmediateCharsForDirection = 500  // 支持 100 题等长序列
        let r = VoiceCommandRecognizer(config: config)

        typealias C = VoiceCommandRecognizer.Command

        // (输入, 本句答案)；答案 = 本句最后一个方向，无方向则为 nil
        let cases: [(input: String, answer: C?)] = [
            ("上", .up),
            ("下", .down),
            ("左", .left),
            ("右", .right),
            ("上继续下", .down),
            ("上继续上下", .down),
            ("上继续下下", .down),
            ("继续上", .up),
            ("继续继续上", .up),
            ("上上上", .up),
            ("左右", .right),
            ("左右上下", .down),
            ("上左下", .down),
            ("朝上", .up),
            ("向左", .left),
            ("往右", .right),
            ("上边", .up),
            ("左边", .left),
            ("继续上边", .up),
            ("上x", .up),
            ("x上", .up),
            ("上x下", .down),
            ("上继续下继续左", .left),
            ("继续", nil),
            ("好的继续", nil),
            ("上一个", .up),
            ("下一个", .down),
            ("继续下一个", .down),
            ("上继续", .up),
            ("上继续上下继续右", .right),
            // 长序列：答案 = 本句最后方向
            ("上继续下继续左继续右", .right),
            ("上继续下继续左继续右继续上", .up),
            ("上继续下继续左继续右继续上继续下", .down),
            ("上继续下继续左继续右继续上继续下继续左", .left),
            ("上继续下继续左继续右继续上继续下继续左继续右", .right),
            ("上继续下继续左继续右继续上继续下继续左继续右继续上", .up),
            ("上继续下继续左继续右继续上继续下继续左继续右继续上继续下", .down),
            ("继续上继续下继续左继续右", .right),
            ("上继续下继续左继续右继续", .right),
            ("上继续下继续左继续右继续继续继续", .right),
        ]

        for (index, c) in cases.enumerated() {
            var dirs: [VoiceCommandRecognizer.Command] = []
            r.onDirectionCommand = { dirs.append($0) }
            r.processTextForTest(c.input)
            let expected = c.answer.map { [$0] } ?? []
            #expect(dirs == expected, "row \(index + 1): 本句答案 expected \(expected), got \(dirs)")
        }
    }
}

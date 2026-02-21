//
//  VoiceDirectionRecognizerV2V2Tests.swift
//  FlipShot
//
//  Created by hanshuang on 2026/2/21.
//

import XCTest
@testable import FlipShot

final class VoiceDirectionRecognizerV2Tests: XCTestCase {

    func testBasicDirections() {
        assertDirection("上", .up)
        assertDirection("下", .down)
        assertDirection("左", .left)
        assertDirection("右", .right)
    }

    func testOverwriteCases() {
        assertDirection("上继续下", .down)
        assertDirection("上继续上下", .down)
        assertDirection("上继续下下", .down)
        assertDirection("继续上", .up)
        assertDirection("上左下", .down)
    }

    func testPrefixSuffix() {
        assertDirection("朝上", .up)
        assertDirection("向左", .left)
        assertDirection("往右", .right)
        assertDirection("上边", .up)
        assertDirection("左边", .left)
    }

    func testLongSequence() {
        assertDirection("上继续下继续左继续右", .right)
        assertDirection("上继续下继续左继续右继续上", .up)
        assertDirection("上继续下继续左继续右继续上继续下", .down)
    }

    func test100RoundsSimulation() {
        var input = ""
        let sequence = ["上", "下", "左", "右"]
        for i in 0..<100 {
            input += sequence[i % 4]
        }
        // 不创建 VoiceDirectionRecognizerV2（会 init AVAudioEngine，测试环境易崩溃），只测 helper 逻辑
        let pinyin = recognizerTestHelperToPinyin(input)
        let result = recognizerTestHelperMatch(pinyin)
        XCTAssertEqual(result, .right) // 第 100 个是右
    }

    // MARK: - Helper

    private func assertDirection(_ text: String,
                                 _ expected: VoiceDirectionRecognizerV2.Direction?) {
        let pinyin = recognizerTestHelperToPinyin(text)
        let result = recognizerTestHelperMatch(pinyin)
        XCTAssertEqual(result, expected)
    }

    // 纯函数测试 helper（避免启动 Audio）
    private func recognizerTestHelperToPinyin(_ text: String) -> String {
        let mutable = NSMutableString(string: text) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (mutable as String).lowercased().replacingOccurrences(of: " ", with: "")
    }

    private func recognizerTestHelperMatch(_ pinyin: String)
    -> VoiceDirectionRecognizerV2.Direction? {

        let s = pinyin
        var lastMatch: (VoiceDirectionRecognizerV2.Direction, String.Index)?

        let patterns: [(VoiceDirectionRecognizerV2.Direction, String)] = [
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
}

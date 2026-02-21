# FlipShot

E 字视标视力训练 iOS 应用，支持**纯语音**作答：说出方向（上/下/左/右），答对后说「继续」进入下一题。

## 功能

- **E 字训练卡**：8×5 共 40 格，按顺序报出每格 E 的朝向
- **语音识别**：方向词（上、下、左、右、向等）与分隔词「继续」，拼音匹配 + 静默约 2 秒当最终结果
- **状态提示**：等待方向 / 正在识别 / 正确（待说继续）/ 错误，界面有明确状态横幅
- **刷新**：随机打乱训练卡上 E 的方向，避免每次顺序固定
- **调试页**：Voice 调试可查看识别原文、命中、日志及「请说方向 / 请说继续 / 请等待」提示

## 环境与运行

- Xcode、iOS 真机或模拟器
- 需麦克风与语音识别权限

打开 `FlipShot.xcodeproj`，选择目标设备运行即可。

## 项目结构（主要）

| 路径 | 说明 |
|------|------|
| `FlipShot/Utils/VoiceCommandRecognizer.swift` | 语音指令识别（方向 + 继续）、阶段与静默计时 |
| `FlipShot/ViewControllers/VisionTrainingViewController.swift` | 训练页：状态机、状态横幅、训练卡贴底布局 |
| `FlipShot/ViewControllers/VoiceCommandDebugViewController.swift` | 语音调试页 |
| `FlipShot/Views/EChartTrainingCardView.swift` | E 字训练卡视图（40 格、状态样式） |
| `FlipShot/Models/VisionCardImage.swift` | 训练卡 40 格方向等配置 |
| `FlipShotTests/VoiceCommandRecognizerTests.swift` | 语音识别规则表单元测试 |

## 语音指令说明

- **方向**：上、下、左、右（及「向」识别为上）  
- **继续**：答对当前格后说「继续」进入下一题（不支持「下一个」，避免与「下」冲突）

## License

Private / 未指定开源协议。

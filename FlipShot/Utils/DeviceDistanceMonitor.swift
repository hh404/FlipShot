//
//  DeviceDistanceMonitor.swift
//  FlipShot
//
//  40cm 用户与设备距离提示：支持 LiDAR 的用测距，不支持的用前置摄像头+人脸尺寸估算。
//

import AVFoundation
import Vision
import UIKit

#if canImport(ARKit)
import ARKit
#endif

/// 距离区间（不暴露具体数字，避免人盯数字眼累）
enum DistanceZone {
    case unknown
    case tooClose   // <30
    case slightlyClose  // 30-35
    case good       // 35-45 绿
    case slightlyFar    // 45-55
    case tooFar     // >55
}

/// 测距结果
struct DistanceReading {
    let distanceCM: Float?
    let inRange: Bool
    let method: String

    var zone: DistanceZone {
        guard let cm = distanceCM else { return .unknown }
        if cm < 30 { return .tooClose }
        if cm < 35 { return .slightlyClose }
        if cm <= 45 { return .good }
        if cm <= 55 { return .slightlyFar }
        return .tooFar
    }
}

/// 设备与用户距离监测：目标约 40cm，支持 LiDAR 与无 LiDAR 算法
final class DeviceDistanceMonitor: NSObject {

    static let targetCM: Float = 40
    static let rangeMinCM: Float = 35
    static let rangeMaxCM: Float = 45

    var onUpdate: ((DistanceReading) -> Void)?

    #if canImport(ARKit)
    private var arSession: ARSession?
    #endif
    private var captureSession: AVCaptureSession?
    private let captureQueue = DispatchQueue(label: "FlipShot.DistanceCapture")
    /// 40cm 时人脸宽度（像素）经验值；iPad 画面大需更大值，否则会卡在约 24cm
    private var faceWidthAt40CM: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 200 : 120
    }
    private var lastFaceWidth: CGFloat?
    private var isUsingLiDAR = false
    /// LiDAR 无有效数据超过此时长则自动切到算法
    private static let lidarFallbackInterval: TimeInterval = 2.0
    private var lastValidLidarTime: CFTimeInterval?
    private var fallbackWorkItem: DispatchWorkItem?

    override init() {
        super.init()
    }

    /// 是否支持 LiDAR 测距
    static var supportsLiDAR: Bool {
        #if canImport(ARKit)
        return ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
        #else
        return false
        #endif
    }

    func start() {
        // 仅用前置人脸算法，不用 LiDAR，避免 iPad Pro 上 Fig 报错与 AR 资源紧张导致卡住
        startFaceBasedEstimate()
    }

    func stop() {
        fallbackWorkItem?.cancel()
        fallbackWorkItem = nil
        lastValidLidarTime = nil
        #if canImport(ARKit)
        arSession?.pause()
        arSession = nil
        #endif
        captureSession?.stopRunning()
        captureSession = nil
    }

    // MARK: - LiDAR

    #if canImport(ARKit)
    private func startLiDAR() {
        fallbackWorkItem?.cancel()
        lastValidLidarTime = nil
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = .smoothedSceneDepth
        config.worldAlignment = .gravity
        let session = ARSession()
        session.delegate = self
        arSession = session
        isUsingLiDAR = true
        session.run(config)
        scheduleLidarFallbackCheck()
    }

    private func scheduleLidarFallbackCheck() {
        fallbackWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.checkLidarFallback()
        }
        fallbackWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + DeviceDistanceMonitor.lidarFallbackInterval, execute: item)
    }

    private func checkLidarFallback() {
        #if canImport(ARKit)
        guard isUsingLiDAR else { return }
        let now = CACurrentMediaTime()
        let noValidRecently = lastValidLidarTime == nil || (now - (lastValidLidarTime ?? 0)) > DeviceDistanceMonitor.lidarFallbackInterval
        if noValidRecently {
            arSession?.pause()
            arSession = nil
            isUsingLiDAR = false
            report(distanceCM: nil, inRange: false, method: "算法")
            // 延迟再启用人脸测距，避免与 AR 争用相机（减少 Fig err=-12784）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startFaceBasedEstimate()
            }
            return
        }
        scheduleLidarFallbackCheck()
        #endif
    }
    #endif

    // MARK: - 无 LiDAR：前置摄像头 + 人脸尺寸估算

    private func startFaceBasedEstimate() {
        isUsingLiDAR = false
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            report(distanceCM: nil, inRange: false, method: "算法")
            return
        }
        if !session.canAddInput(input) {
            report(distanceCM: nil, inRange: false, method: "算法")
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: captureQueue)
        output.alwaysDiscardsLateVideoFrames = true
        if !session.canAddOutput(output) {
            report(distanceCM: nil, inRange: false, method: "算法")
            return
        }
        session.addOutput(output)
        captureSession = session
        captureQueue.async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    /// 根据人脸框宽度估算距离（厘米）：distance ≈ 40 * (faceWidthAt40CM / observedWidth)
    private func estimateDistanceCM(faceWidthPixels: CGFloat) -> Float {
        guard faceWidthPixels > 10 else { return 0 }
        let d = Float(DeviceDistanceMonitor.targetCM) * Float(faceWidthAt40CM) / Float(faceWidthPixels)
        return max(20, min(80, d))
    }

    private func report(distanceCM: Float?, inRange: Bool, method: String) {
        let reading = DistanceReading(distanceCM: distanceCM, inRange: inRange, method: method)
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(reading)
        }
    }
}

// MARK: - ARSessionDelegate (LiDAR)

#if canImport(ARKit)
extension DeviceDistanceMonitor: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isUsingLiDAR else { return }
        let depth = frame.smoothedSceneDepth ?? frame.sceneDepth
        guard let depthMap = depth?.depthMap else { return }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return }
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let centerY = min(height / 2, height - 1)
        let centerX = min(width / 2, width - 1)
        let stride = CVPixelBufferGetBytesPerRow(depthMap)
        let bytesPerPixel = 4
        let offset = centerY * stride + centerX * bytesPerPixel
        let value = (base + offset).load(as: Float32.self)
        guard value.isFinite, value > 0.1, value < 2.0 else { return }
        lastValidLidarTime = CACurrentMediaTime()
        let distanceCM = value * 100
        let inRange = distanceCM >= DeviceDistanceMonitor.rangeMinCM && distanceCM <= DeviceDistanceMonitor.rangeMaxCM
        report(distanceCM: distanceCM, inRange: inRange, method: "LiDAR")
    }
}
#endif

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (人脸估算)

extension DeviceDistanceMonitor: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        try? handler.perform([request])
        guard let results = request.results, let face = results.first else {
            lastFaceWidth = nil
            report(distanceCM: nil, inRange: false, method: "算法")
            return
        }
        let w = face.boundingBox.width * CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        lastFaceWidth = w
        let cm = estimateDistanceCM(faceWidthPixels: w)
        let inRange = cm >= DeviceDistanceMonitor.rangeMinCM && cm <= DeviceDistanceMonitor.rangeMaxCM
        report(distanceCM: cm, inRange: inRange, method: "算法")
    }
}

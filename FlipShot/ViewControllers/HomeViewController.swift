//
//  HomeViewController.swift
//  FlipShot
//
//  首页：校准 + 开始训练（开始训练前请求相机权限，避免训练页 Fig 报错）
//

import UIKit
import AVFoundation

final class HomeViewController: UIViewController {
    
    /// 高对比度：浅色模式纯黑字、深色模式纯白字，不依赖系统 label 避免看不见
    private static let contrastTextColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 1) : UIColor(white: 0, alpha: 1)
    }

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "E字视标训练"
        l.font = .systemFont(ofSize: 42, weight: .bold)
        l.textColor = HomeViewController.contrastTextColor
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "先校准，再训练"
        l.font = .systemFont(ofSize: 28, weight: .semibold)
        l.textColor = HomeViewController.contrastTextColor
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let calibrationButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("校准", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
        b.backgroundColor = .systemOrange
        b.setTitleColor(UIColor(white: 1, alpha: 1), for: .normal)
        b.layer.cornerRadius = 20
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let startButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("开始训练", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
        b.backgroundColor = .systemGreen
        b.setTitleColor(UIColor(white: 1, alpha: 1), for: .normal)
        b.layer.cornerRadius = 20
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(calibrationButton)
        view.addSubview(startButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            calibrationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            calibrationButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 60),
            calibrationButton.widthAnchor.constraint(equalToConstant: 220),
            calibrationButton.heightAnchor.constraint(equalToConstant: 70),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.topAnchor.constraint(equalTo: calibrationButton.bottomAnchor, constant: 24),
            startButton.widthAnchor.constraint(equalToConstant: 220),
            startButton.heightAnchor.constraint(equalToConstant: 70),
        ])
        
        calibrationButton.addTarget(self, action: #selector(calibrationTapped), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestCameraPermissionIfNeeded()
    }

    /// 首页一进入就申请相机权限，避免进训练页再碰相机触发 Fig 报错
    private func requestCameraPermissionIfNeeded() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .video) { _ in }
    }
    
    @objc private func calibrationTapped() {
        let calibration = CalibrationViewController()
        calibration.modalPresentationStyle = .fullScreen
        present(calibration, animated: true)
    }
    
    @objc private func startTapped() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentVisionTraining()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentVisionTraining()
                    } else {
                        self?.showCameraDeniedAlert()
                    }
                }
            }
        case .denied, .restricted:
            showCameraDeniedAlert()
        @unknown default:
            presentVisionTraining()
        }
    }

    private func presentVisionTraining() {
        let training = VisionTrainingViewController()
        training.modalPresentationStyle = .fullScreen
        present(training, animated: true)
    }

    private func showCameraDeniedAlert() {
        let alert = UIAlertController(
            title: "需要相机权限",
            message: "用于 40cm 距离提示，请在「设置 → FlipShot」中开启相机。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

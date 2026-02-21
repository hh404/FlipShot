//
//  HomeViewController.swift
//  FlipShot
//
//  首页：校准 + 开始训练
//

import UIKit

final class HomeViewController: UIViewController {
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "E字视标训练"
        l.font = .systemFont(ofSize: 42, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "先校准，再训练"
        l.font = .systemFont(ofSize: 22, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let calibrationButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("校准", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
        b.backgroundColor = .systemOrange
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 20
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let startButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("开始训练", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
        b.backgroundColor = .systemGreen
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 20
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
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
    
    @objc private func calibrationTapped() {
        let calibration = CalibrationViewController()
        calibration.modalPresentationStyle = .fullScreen
        present(calibration, animated: true)
    }
    
    @objc private func startTapped() {
        let training = VisionTrainingViewController()
        training.modalPresentationStyle = .fullScreen
        present(training, animated: true)
    }
}

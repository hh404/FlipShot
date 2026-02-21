//
//  PrepareViewController.swift
//  FlipShot
//
//  准备页：语音提示 + 大按钮「我准备好了」
//

import UIKit

final class PrepareViewController: UIViewController {
    
    private let config: FlipShotConfig
    
    private let hintLabel: UILabel = {
        let l = UILabel()
        l.text = "把 iPad 放好\n眼睛看着屏幕"
        l.font = .systemFont(ofSize: 32, weight: .medium)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let readyButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("我准备好了", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 32, weight: .bold)
        b.backgroundColor = .systemBlue
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 24
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("返回", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    init(config: FlipShotConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        view.addSubview(hintLabel)
        view.addSubview(readyButton)
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            hintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            readyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            readyButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 64),
            readyButton.widthAnchor.constraint(equalToConstant: 280),
            readyButton.heightAnchor.constraint(equalToConstant: 80),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
        ])
        
        readyButton.addTarget(self, action: #selector(readyTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        VoiceManager.shared.sayGetReady()
    }
    
    @objc private func readyTapped() {
        VoiceManager.shared.stop()
        let training = TrainingViewController(config: config, roundIndex: 0)
        training.modalPresentationStyle = .fullScreen
        training.onDismiss = { [weak self] in self?.dismiss(animated: true) }
        present(training, animated: true)
    }
    
    @objc private func backTapped() {
        VoiceManager.shared.stop()
        dismiss(animated: true)
    }
}

//
//  DoneViewController.swift
//  FlipShot
//
//  结束页：鼓励 + 再练一次 / 返回
//

import UIKit

final class DoneViewController: UIViewController {
    
    private let config: FlipShotConfig
    
    var onDismiss: (() -> Void)?
    /// 再练一次：先 dismiss 到首页，再由首页 present 准备页
    var onAgain: ((FlipShotConfig) -> Void)?
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "今天练完了，真棒！"
        l.font = .systemFont(ofSize: 36, weight: .bold)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let againButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("再练一次", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
        b.backgroundColor = .systemGreen
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 20
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("返回首页", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 24, weight: .medium)
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
        
        view.addSubview(titleLabel)
        view.addSubview(againButton)
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            againButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            againButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 56),
            againButton.widthAnchor.constraint(equalToConstant: 220),
            againButton.heightAnchor.constraint(equalToConstant: 72),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.topAnchor.constraint(equalTo: againButton.bottomAnchor, constant: 24),
        ])
        
        againButton.addTarget(self, action: #selector(againTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }
    
    @objc private func againTapped() {
        VoiceManager.shared.stop()
        onAgain?(config)
    }
    
    @objc private func backTapped() {
        onDismiss?()
    }
}

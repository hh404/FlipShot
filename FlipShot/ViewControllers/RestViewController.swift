//
//  RestViewController.swift
//  FlipShot
//
//  组间休息：倒计时 + 语音「休息一下」
//

import UIKit

final class RestViewController: UIViewController {
    
    private let config: FlipShotConfig
    private let nextRoundIndex: Int
    
    var onDismiss: (() -> Void)?
    
    private var countdown: Int
    private var timer: Timer?
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "休息一下"
        l.font = .systemFont(ofSize: 36, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let countLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 72, weight: .bold)
        l.textAlignment = .center
        l.textColor = .systemOrange
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let nextLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 22, weight: .medium)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    init(config: FlipShotConfig, nextRoundIndex: Int) {
        self.config = config
        self.nextRoundIndex = nextRoundIndex
        self.countdown = Int(config.restDuration)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        view.addSubview(titleLabel)
        view.addSubview(countLabel)
        view.addSubview(nextLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            countLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            nextLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 32),
        ])
        
        countLabel.text = "\(countdown)"
        nextLabel.text = "下一组：第 \(nextRoundIndex + 1) 组"
        
        VoiceManager.shared.sayRest(seconds: countdown)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.tolerance = 0.2
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    private func tick() {
        countdown -= 1
        countLabel.text = "\(max(0, countdown))"
        if countdown <= 0 {
            timer?.invalidate()
            timer = nil
            let training = TrainingViewController(config: config, roundIndex: nextRoundIndex)
            training.modalPresentationStyle = .fullScreen
            training.onDismiss = onDismiss
            present(training, animated: true)
        }
    }
}

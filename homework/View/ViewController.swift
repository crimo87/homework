//
//  ViewController.swift
//  homework
//
//  Created by SNOW on 2019. 1. 25..
//  Copyright © 2019년 gm. All rights reserved.
//

import UIKit
import RxSwift

class ViewController: UIViewController {

    @IBOutlet weak var transitionButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageContainer: UIView!
    @IBOutlet weak var backImageView: UIImageView!
    @IBOutlet weak var frontImageView: UIImageView!
    
    @IBAction func onTapStart(_ sender: UIButton) {
        sender.isEnabled = false

        self.viewModel?.start()
    }

    @IBAction func onTapTime(_ sender: UIButton) {
        let alert = UIAlertController(title: "전환 시간", message: "이미지 전환 시간을 선택해주세요.", preferredStyle: .alert)

        for i in 1...10 {
            alert.addAction(UIAlertAction(title: "\(i)초", style: i == self.viewModel?.transitionSec ? .destructive : .default, handler: { [weak self] (_) in
                self?.viewModel?.transitionSec = i
                self?.updateButton(transitionSec: i)
            }))
        }

        alert.addAction(UIAlertAction(title: "취소", style: .default, handler: { (_) in }))

        self.present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupViewModel()
        self.setupView()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private let disposeBag =  DisposeBag()
    private var viewModel: ViewModel?
}

extension ViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageContainer
    }
}

extension ViewController {
    
    private func setupViewModel() {
        self.viewModel = ImageViewModel(transitionSec: Int.defaultTransitionSec)
        self.viewModel?.currentImage.subscribe(onNext: { self.changeToImage($0) })
            .disposed(by: self.disposeBag)
        self.viewModel?.isLoading.subscribe(onNext: { if $0 { self.showErrorAlert() }})
            .disposed(by: self.disposeBag)
    }
    
    private func setupView() {
        self.scrollView.minimumZoomScale = 1
        self.scrollView.maximumZoomScale = 3
        self.updateButton(transitionSec: Int.defaultTransitionSec)
    }
    
    private func updateButton(transitionSec: Int) {
        self.transitionButton.setTitle("전환 시간 : \(transitionSec)초", for: .normal)
    }
    
    private func changeToImage(_ image: UIImage) {
        self.backImageView.alpha = 0
        self.backImageView.image = image
        
        UIView.animate(withDuration: 0.25, animations: {
            self.backImageView.alpha = 1
            self.frontImageView.alpha = 0
        }) { [weak self] (_) in
            self?.frontImageView.alpha = 1
            self?.frontImageView.image = self?.backImageView.image
        }
    }
    
    private func showErrorAlert() {
        guard self.presentedViewController == nil else { return }

        let alert = UIAlertController(title: "알림", message: "이미지를 가져오는 중입니다.\n잠시만 기다려주세요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default, handler: { (_) in }))
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: Static Value
fileprivate extension Int {
    
    static let defaultTransitionSec = 3
}

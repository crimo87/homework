//
//  ViewModel.swift
//  homework
//
//  Created by SNOW on 2019. 1. 25..
//  Copyright © 2019년 gm. All rights reserved.
//

import UIKit
import RxSwift
import RxAlamofire

protocol ViewModel {
    var isLoading: BehaviorSubject<Bool>        { get }
    var transitionSec: BehaviorSubject<Int>     { get }
    var currentImage: PublishSubject<UIImage>   { get }
    
    func start()
    func updateTransitionSec(_ transitionSec: Int)
}

class ImageViewModel: ViewModel {
    
    let isLoading: BehaviorSubject<Bool>
    let transitionSec: BehaviorSubject<Int>
    let currentImage: PublishSubject<UIImage>

    init(transitionSec: Int) {
        self.isLoading = BehaviorSubject(value: false)
        self.transitionSec = BehaviorSubject(value: transitionSec)
        self.currentImage = PublishSubject()
        self.setup()
        self.request()
    }
    
    func start() {
        self.changeImage()
        self.transitionSec
            .subscribeOn(MainScheduler.instance)
            .flatMapLatest({ transitionSec in Observable<Int>.interval(RxTimeInterval(transitionSec), scheduler: MainScheduler.instance) })
            .subscribe(onNext: { _ in self.changeImage() })
            .disposed(by: disposeBag)
    }
    
    func updateTransitionSec(_ transitionSec: Int) {
        self.transitionSec.onNext(transitionSec)
    }
    
    private func changeImage() {
        if self.images.count > 0 {
            self.currentImage.onNext(self.images.removeFirst().1)
        } else {
            self.isLoading.onNext(true)
        }
    }
    
    private func setup() {
        Observable<Int>.interval(RxTimeInterval(1), scheduler: MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            .flatMap({ _ in self.model.map { Observable.just($0) } ?? Observable.empty() })
            .flatMap({ model in Observable.from(model.items) })
            .filter({ item in self.canDownloadImage(url: item.media.m) })
            .map({ item in URL(string: item.media.m) })
            .flatMap({ url in url.map ({ Observable.just($0) }) ?? Observable.empty() })
            .filter({ _ in self.images.count + self.requests.count < Int.maxPreloadCount })
            .do(onNext: { url in self.requests.append(url.absoluteString) })
            .flatMap({ url in RxAlamofire.requestData(.get, url) })
            .subscribe(onNext: { (response, data)  in
                guard let url = response.url?.absoluteString, let image = UIImage(data: data) else { return }
                self.images.append((url, image))
                self.requests.removeAll(where: { $0 == url})
                self.model?.items.removeAll(where: { $0.media.m == url })
                
                if self.model?.items.count == 0 { self.request() }
            })
            .disposed(by: self.disposeBag)
    }

    private func canDownloadImage(url: String) -> Bool{
        return self.images.count + self.requests.count < Int.maxPreloadCount && (!self.images.contains(where: { $0.0 == url }) || !self.requests.contains(url))
    }
    
    private func request() {
        guard let url = URL(string: String.requestUrl) else { return }
        
        RxAlamofire.requestData(.get, url, parameters: ["format":"json"])
            .subscribeOn(MainScheduler.instance)
            .throttle(Double.requestTimeout, scheduler: MainScheduler.instance)
            .timeout(Double.requestThrottle, scheduler: MainScheduler.instance)
            .retry(Int.maxRetryCount)
            .map({ (response, data) -> BasicModel in  try NetworkUtil.convertToModel(data: data) })
            .subscribe(onNext: { (result: BasicModel) in
                if result.modified != self.model?.modified { self.model = result }
            }, onError: { _ in
                self.isLoading.onNext(true)
            })
            .disposed(by: self.disposeBag)
    }
    
    private var model: BasicModel?
    private var images = [(String, UIImage)]()
    private var requests = [String]()
    
    private let disposeBag =  DisposeBag()
}

// MARK: Static Value
fileprivate extension Int {
    
    static let maxPreloadCount = 5
    static let maxRetryCount = 3
}

fileprivate extension Double {
    
    static let requestTimeout = 5.0
    static let requestThrottle = 5.0
}

fileprivate extension String {
    
    static let requestUrl = "https://api.flickr.com/services/feeds/photos_public.gne"
}

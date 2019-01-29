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
import Alamofire

protocol ViewModel {
    var transitionSec: Int?                 { get set }
    var isLoading: Observable<Bool>         { get }
    var currentImage: Observable<UIImage>   { get }
    
    func start()
}

class ImageViewModel: ViewModel {
    
    var transitionSec: Int? {
        set { self.updateTransitionSec(newValue) }
        get { return try? self.transitionSecSubject.value() }
    }

    var isLoading: Observable<Bool>         { return isLoadingSubject       }
    var currentImage: Observable<UIImage>   { return currentImageSubject    }

    
    init(transitionSec: Int) {
        self.isLoadingSubject = BehaviorSubject(value: false)
        self.transitionSecSubject = BehaviorSubject(value: transitionSec)
        self.currentImageSubject = PublishSubject()
        self.setupFetch()
        self.request()
    }
    
    func start() {
        self.changeImage()
        self.transitionSecSubject
            .subscribeOn(MainScheduler.instance)
            .flatMapLatest({ transitionSec in Observable<Int>.interval(RxTimeInterval(transitionSec), scheduler: MainScheduler.instance) })
            .subscribe(onNext: { _ in self.changeImage() })
            .disposed(by: disposeBag)
    }
    
    private func updateTransitionSec(_ transitionSec: Int?) {
        guard let transitionSec = transitionSec else { return }
        self.transitionSecSubject.onNext(transitionSec)
    }
    
    private func changeImage() {
        if self.images.count > 0 {
            self.currentImageSubject.onNext(self.images.removeFirst().1)
        } else {
            self.isLoadingSubject.onNext(true)
        }
    }
    
    private func setupFetch() {
        
        Observable<Int>.interval(RxTimeInterval(Int.fetchInterval), scheduler: MainScheduler.instance)
            .flatMap({ _ in self.model.map { Observable.just($0) } ?? Observable.empty() })
            .do(onNext: { model in if model.items.count < Int.maxPreloadCount { self.request() } })
            .flatMap({ Observable.from($0.items) })
            .filter({ self.canDownloadImage(url: $0.media.m) })
            .map({ URL(string: $0.media.m) })
            .flatMap({ url in url.map ({ Observable.just($0) }) ?? Observable.empty() })
            .do(onNext: { url in self.requests.insert(url.absoluteString) })
            .observeOn(ConcurrentDispatchQueueScheduler(qos: DispatchQoS.background))
            .flatMap({ url in SessionManager.default.rx.responseData(.get, url) })
            .observeOn(MainScheduler.instance)
            .do(onError: { (error) in self.requests.removeAll() })
            .retry()
            .subscribe(onNext: { (response, data)  in
                guard let url = response.url?.absoluteString, let image = UIImage(data: data) else { return }

                if let deletedUrl = self.requests.remove(url) {
                    self.images.append((deletedUrl, image))
                    self.model?.items.removeAll(where: { $0.media.m == deletedUrl })
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func canDownloadImage(url: String) -> Bool{
        return self.images.count + self.requests.count < Int.maxPreloadCount
            && self.images.count + self.requests.count < Int.maxPreloadCount
            && !self.images.contains(where: { $0.0 == url })
            && !self.requests.contains(url)
    }
    
    private func request() {
        guard let url = URL(string: String.requestUrl) else { return }
        
        SessionManager.default.rx.responseData(.get, url, parameters: ["format":"json"])
            .throttle(Double.requestThrottle, scheduler: MainScheduler.instance)
            .timeout(Double.requestTimeout, scheduler: MainScheduler.instance)
            .retry()
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .default))
            .map({ (response, data) -> BasicModel in  try NetworkUtil.convertToModel(data: data) })
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { (result: BasicModel) in
                if result.modified != self.model?.modified { self.model = result }
            })
            .disposed(by: self.disposeBag)
    }
    
    private var model: BasicModel?
    private var images = [(String, UIImage)]()
    private var requests = Set<String>()
    
    private let isLoadingSubject: BehaviorSubject<Bool>
    private let transitionSecSubject: BehaviorSubject<Int>
    private let currentImageSubject: PublishSubject<UIImage>
    private let disposeBag =  DisposeBag()
}

// MARK: Static Value
fileprivate extension Int {
    static let fetchInterval = 1
    static let maxPreloadCount = 5
}

fileprivate extension Double {
    
    static let requestTimeout = 5.0
    static let requestThrottle = 5.0
}

fileprivate extension String {
    
    static let requestUrl = "https://api.flickr.com/services/feeds/photos_public.gne"
}

//
//  BasicModel.swift
//  homework
//
//  Created by SNOW on 2019. 1. 25..
//  Copyright © 2019년 gm. All rights reserved.
//

import Foundation

struct BasicModel: Codable {
    let modified: String
    var items: [BasicItem]
}

struct BasicItem: Codable {
    let media: MediaModel
}

struct MediaModel: Codable {
    let m: String
}

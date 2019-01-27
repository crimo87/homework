//
//  NetworkUtil.swift
//  homework
//
//  Created by SNOW on 2019. 1. 25..
//  Copyright © 2019년 gm. All rights reserved.
//

import Foundation

class NetworkUtil {
    
    static func convertToModel<T:Codable>(data: Data) throws -> T {
        guard let jsonFirstIndex = data.firstIndex(where: { self.jsonPrefixArray.contains($0) }),
            let jsonLastIndex = data.lastIndex(where: { self.jsonSuffixArray.contains($0) }) else {
                throw NSError()
        }
        return try JSONDecoder().decode(T.self, from: data[jsonFirstIndex...jsonLastIndex])
    }
    
    private static let jsonPrefixArray: [UInt8] = [UInt8("{".unicodeScalars.first!.value), UInt8("[".unicodeScalars.first!.value)]
    private static let jsonSuffixArray: [UInt8] = [UInt8("}".unicodeScalars.first!.value), UInt8("]".unicodeScalars.first!.value)]
}

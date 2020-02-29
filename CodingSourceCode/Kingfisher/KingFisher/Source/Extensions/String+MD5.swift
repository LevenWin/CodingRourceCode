//
//  File.swift
//  KingFisher
//
//  Created by leven on 2020/2/25.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import CommonCrypto
extension String: KingfisherCompatibleValue { }
extension KingfisherWrapper where Base == String {
    var md5: String {
        guard let data = base.data(using: .utf8) else {
            return base
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        #if swift(>=5.0)
        _ = data.withUnsafeBytes({ (bytes: UnsafeRawBufferPointer) in
            return CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        })
        #else
        _ = data.withUnsafeBytes { bytes in
            return CC_MD5(bytes, CC_LONG(data.count), &digest)
        }
        #endif
        return digest.reduce(into: "") {
            $0 += String(format: "%02x", $1)
        }
    }
}

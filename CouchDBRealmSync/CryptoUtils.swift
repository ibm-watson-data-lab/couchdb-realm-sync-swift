//
//  RealmCloudantPullReplicator.swift
//  LocationTracker
//
//  Created by Mark Watson on 7/29/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import CryptoSwift
import Foundation

public class CryptoUtils {
    
    static let SHA1_DIGEST_LENGTH = 20
    
    public static func sha1(input: NSData) -> String {
        let hash = input.arrayOfBytes().sha1()
        return hexStringFromData(NSData(bytes: hash, length: SHA1_DIGEST_LENGTH))
    }
    
    private static func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](count: input.length, repeatedValue: 0)
        input.getBytes(&bytes, length: input.length)
        var hexString = ""
        for byte in bytes {
            hexString += String(format:"%02x", UInt8(byte))
        }
        return hexString
    }
}

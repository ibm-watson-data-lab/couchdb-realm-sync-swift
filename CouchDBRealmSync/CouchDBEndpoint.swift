//
//  RemoteEndpoint.swift
//  LocationTracker
//
//  Created by Mark Watson on 8/1/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Foundation

public class CouchDBEndpoint: CustomStringConvertible {
    
    var baseUrl: String
    var username: String?
    var password: String?
    var db: String
    
    public init(baseUrl: String, username: String?, password: String?, db: String) {
        self.baseUrl = baseUrl
        self.username = username
        self.password = password
        self.db = db
    }
    
    public var description: String {
        return "\(self.baseUrl)/\(self.db)"
    }
}
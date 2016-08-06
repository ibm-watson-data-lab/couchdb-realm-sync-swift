//
//  CouchDBDocMissingRevs.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation

public class CouchDBDocMissingRevs {
    
    var docId: String
    var missingRevs: [String]
    
    init(docId: String, missingRevs: [String]) {
        self.docId = docId
        self.missingRevs = missingRevs
    }
}

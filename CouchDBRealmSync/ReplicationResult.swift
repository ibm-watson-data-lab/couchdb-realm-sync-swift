//
//  ReplicationResult.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation

public class ReplicationResult {
    
    public var replicator: Replicator
    public var success: Bool
    public var changesProcessed: Int
    public var error: ErrorType?
    public var errorMessage: String?
    
    init(replicator: Replicator, changesProcessed: Int) {
        self.replicator = replicator
        self.success = true
        self.changesProcessed = changesProcessed
    }
    
    init(replicator: Replicator, error: ErrorType?, errorMessage: String?) {
        self.replicator = replicator
        self.success = false
        self.changesProcessed = 0
        self.error = error
        self.errorMessage = errorMessage
    }
}

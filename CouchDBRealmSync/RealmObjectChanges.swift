//
//  RealmObjectChanges.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/2/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation

class RealmObjectChanges {
    
    var lastSequence: Int64
    var realmDocMaps: [RealmObjectCouchDBDocMap]
    
    init(lastSequence: Int64, realmDocMaps: [RealmObjectCouchDBDocMap]) {
        self.lastSequence = lastSequence
        self.realmDocMaps = realmDocMaps
    }
    
}
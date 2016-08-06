//
//  RealmObjectCouchDBSequence.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

/**
 One instance of this object is stored in Realm
 for each Realm object type that has been registered for replication.
 */
class RealmObjectCouchDBSequence : Object {
    
    dynamic var realmObjectType: String?
    dynamic var realmObjectReplicatorId: String = NSUUID().UUIDString
    dynamic var lastPushSequence: Int64 = 0
    dynamic var lastPullSequence: String?
    
    override class func primaryKey() -> String? {
        return "realmObjectType"
    }
    
    required init() {
        super.init()
    }
    
    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    required init(value: AnyObject, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    init(realmObjectType: String, lastPushSequence: Int64, lastPullSequence: String?) {
        self.realmObjectType = realmObjectType;
        self.lastPushSequence = lastPushSequence
        self.lastPullSequence = lastPullSequence
        super.init()
    }
}
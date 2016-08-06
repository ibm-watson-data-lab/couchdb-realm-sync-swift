//
//  RealmObjectCouchDBDocMap.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/2/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Realm
import RealmSwift

/**
 One instance of this class is stored in Realm
 for each Realm object that is being tracked for replication.
 */
class RealmObjectCouchDBDocMap : Object {
    
    dynamic var realmObjectType: String?
    dynamic var realmObjectId: String?
    dynamic var couchDocId: String?
    dynamic var couchRev: String?
    dynamic var couchSequence: Int64 = 0
    
    required init() {
        super.init()
    }
    
    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    required init(value: AnyObject, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    init(realmObjectType: String, realmObjectId: String, couchDocId: String, couchRev: String, couchSequence: Int64) {
        self.realmObjectType = realmObjectType;
        self.realmObjectId = realmObjectId
        self.couchDocId = couchDocId
        self.couchRev = couchRev
        self.couchSequence = couchSequence
        super.init()
    }
    
}

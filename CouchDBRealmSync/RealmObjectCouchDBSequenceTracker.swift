//
//  RealmObjectCouchDBSequenceTracker.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

class RealmObjectCouchDBSequenceTracker {
    
    var realmObjectType: String
    var notificationToken: NotificationToken?
    
    init(realmObjectType: String) {
        self.realmObjectType = realmObjectType
    }
    
    func start(realm: Realm, completionHandler: (result: RealmObjectCouchDBSequence) -> Void) {
        let results = realm.objects(RealmObjectCouchDBSequence.self).filter("realmObjectType = '\(self.realmObjectType)'")
        self.notificationToken = results.addNotificationBlock { (changes) in
            switch changes {
            case .Initial(let results):
                for obj in results {
                    completionHandler(result: obj)
                }
                break
            case .Update(let results, _, let insertions, let modifications):
                for idx in insertions {
                    completionHandler(result: results[idx])
                }
                for idx in modifications {
                    completionHandler(result: results[idx])
                }
                break
            case .Error(let err):
                fatalError("\(err)")
            }
        }
        if (results.count == 0) {
            let realmLastSeq = RealmObjectCouchDBSequence(realmObjectType: "\(realmObjectType)", lastPushSequence: Int64(0), lastPullSequence: nil)
            try! realm.write {
                realm.add(realmLastSeq)
            }
        }
    }
    
    func stop(realm: Realm) {
        if (self.notificationToken != nil) {
            self.notificationToken?.stop()
            self.notificationToken = nil
        }
    }
    
    func updateLastPushSequence(realm: Realm, lastPushSequence: Int64) {
        let results = realm.objectForPrimaryKey(RealmObjectCouchDBSequence.self, key: self.realmObjectType)
        if (results == nil) {
            let realmLastSeq = RealmObjectCouchDBSequence(realmObjectType: "\(self.realmObjectType)", lastPushSequence: lastPushSequence, lastPullSequence: nil)
            try! realm.write {
                realm.add(realmLastSeq)
            }
        }
        else {
            try! realm.write {
                results!.lastPushSequence = lastPushSequence
                realm.add(results!)
            }
        }
    }
    
    func updateLastPullSequence(realm: Realm, lastPullSequence: String) {
        let results = realm.objectForPrimaryKey(RealmObjectCouchDBSequence.self, key: self.realmObjectType)
        if (results == nil) {
            let realmLastSeq = RealmObjectCouchDBSequence(realmObjectType: "\(self.realmObjectType)", lastPushSequence: Int64(0), lastPullSequence: lastPullSequence)
            try! realm.write {
                realm.add(realmLastSeq)
            }
        }
        else {
            try! realm.write {
                results!.lastPullSequence = lastPullSequence
                realm.add(results!)
            }
        }
    }
}

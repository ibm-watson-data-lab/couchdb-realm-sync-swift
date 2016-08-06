//
//  ReplicationManager.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

public enum ReplicationManagerError: ErrorType {
    case PrimaryKeyRequired
}

public class ReplicationManager {
    
    var realm: Realm
    var realmObjectManagers: [String:AnyObject] = [:]
    var lastSequenceTrackers: [String:RealmObjectCouchDBSequenceTracker] = [:]
    var lastSequences: [String:RealmObjectCouchDBSequence] = [:]
    
    public init(realm: Realm) {
        self.realm = realm
    }
    
    public func register<T: Object>(realmObjectType: T.Type) throws {
        if (realmObjectType.primaryKey() == nil) {
            throw ReplicationManagerError.PrimaryKeyRequired
        }
        self.register(RealmObjectManager(idField: T.primaryKey()!, type: realmObjectType))
    }
    
    public func register<T: Object>(realmObjectMgr: RealmObjectManager<T>) {
        let realmObjectType = realmObjectMgr.getObjectType().className()
        self.realmObjectManagers[realmObjectType] = realmObjectMgr
        self.lastSequenceTrackers[realmObjectType] = RealmObjectCouchDBSequenceTracker(realmObjectType: realmObjectType)
        self.lastSequenceTrackers[realmObjectType]?.start(realm, completionHandler: { (result) in
            self.lastSequences[realmObjectType] = result
        })
        realmObjectMgr.startMonitoringObjectChanges(realm) { (changes) in
            self.processObjectChanges(realmObjectMgr, changes: changes)
        }
    }
    
    public func deregister<T: Object>(realmObjectMgr: RealmObjectManager<T>) {
        realmObjectMgr.stopMonitoringObjectChanges(realm)
    }
    
    public func pull<T:Object>(source: CouchDBEndpoint, target: T.Type) throws -> PullReplicator<T> {
        let realmObjectMgr = self.realmObjectManagers[target.className()] as! RealmObjectManager<T>
        return PullReplicator(source: source, realmObjectMgr: realmObjectMgr, replicationMgr: self)
    }
    
    public func push<T:Object>(source: T.Type, target: CouchDBEndpoint) throws -> PushReplicator<T> {
        let realmObjectMgr = self.realmObjectManagers[source.className()] as! RealmObjectManager<T>
        return PushReplicator(target: target, realmObjectMgr: realmObjectMgr, replicationMgr: self)
    }
    
    // MARK: Internal Functions
    
    func getRealmObjectReplicatorId<T: Object>(realmObjectMgr: RealmObjectManager<T>) -> String {
        return self.lastSequences[realmObjectMgr.getObjectType().className()]!.realmObjectReplicatorId
    }
    
    func processObjectChanges<T: Object>(realmObjectMgr: RealmObjectManager<T>, changes: RealmCollectionChange<Results<T>>) {
        switch changes {
        case .Initial:
            // if there are no mappings then initialize the mappings table
            if (self.atleastOneObjectMappingsExists(realmObjectMgr) == false) {
                self.addMissingObjectMappings(realmObjectMgr)
            }
            break
        case .Update(let results, let deletions, let insertions, let modifications):
            self.removeObjectMappings(realmObjectMgr, realmObjects: Array(results), indexes: deletions)
            self.addObjectMappings(realmObjectMgr, realmObjects: Array(results), indexes: insertions)
            self.addOrUpdateObjectMappings(realmObjectMgr, realmObjects: Array(results), indexes: modifications)
            break
        case .Error(let err):
            // An error occurred while opening the Realm file on the background worker thread
            fatalError("\(err)")
            break
        }

    }
    
    func atleastOneObjectMappingsExists<T: Object>(realmObjectMgr: RealmObjectManager<T>) -> Bool {
        let realmDocMaps = self.realm.objects(RealmObjectCouchDBDocMap.self).filter("realmObjectType = '\(realmObjectMgr.getObjectType().className())'")
        return realmDocMaps.count > 0
    }
    
    func addMissingObjectMappings<T: Object>(realmObjectMgr: RealmObjectManager<T>) {
        var realmObjectIds: [String] = []
        let realmDocMaps = self.realm.objects(RealmObjectCouchDBDocMap.self).filter("realmObjectType = '\(realmObjectMgr.getObjectType().className())'")
        if (realmDocMaps.count > 0) {
            for realmDocMap in realmDocMaps {
                realmObjectIds.append(realmDocMap.realmObjectId!)
            }
        }
        var sequence = self.lastSequences[realmObjectMgr.getObjectType().className()]?.lastPushSequence ?? Int64(0)
        let realmObjects = realmObjectMgr.getObjectsNotMatchingIds(realm, ids: realmObjectIds)
        for realmObject in realmObjects {
            sequence += Int64(1)
            self.addObjectMapping(realmObjectMgr, realmObject: realmObject, sequence: sequence)
        }
        self.lastSequenceTrackers[realmObjectMgr.getObjectType().className()]?.updateLastPushSequence(realm, lastPushSequence: sequence)
    }
    
    func addObjectMappings<T: Object>(realmObjectMgr: RealmObjectManager<T>, realmObjects: [T], indexes: [Int]) {
        if (indexes.count > 0) {
            var sequence = self.lastSequences[realmObjectMgr.getObjectType().className()]?.lastPushSequence ?? Int64(0)
            for idx in indexes {
                sequence += Int64(1)
                self.addObjectMapping(realmObjectMgr, realmObject:realmObjects[idx], sequence: sequence)
            }
            self.lastSequenceTrackers[realmObjectMgr.getObjectType().className()]?.updateLastPushSequence(realm, lastPushSequence: sequence)
        }
    }
    
    func addObjectMapping<T: Object>(realmObjectMgr: RealmObjectManager<T>, realmObject: T, sequence: Int64) {
        let couchDocId = NSUUID().UUIDString
        let couchRev = "1-\(NSUUID().UUIDString)"
        let realmDocMap = RealmObjectCouchDBDocMap(realmObjectType: "\(realmObjectMgr.getObjectType().className())", realmObjectId: realmObjectMgr.getObjectId(realmObject), couchDocId: couchDocId, couchRev: couchRev, couchSequence: sequence)
        try! self.realm.write {
            self.realm.add(realmDocMap)
        }
    }
    
    func addOrUpdateObjectMappings<T: Object>(realmObjectMgr: RealmObjectManager<T>, realmObjects: [T], indexes: [Int]) {
        if (indexes.count > 0) {
            var sequence = self.lastSequences[realmObjectMgr.getObjectType().className()]?.lastPushSequence ?? Int64(0)
            for idx in indexes {
                sequence += Int64(1)
                self.addOrUpdateObjectMapping(realmObjectMgr, realmObject:realmObjects[idx], sequence: sequence)
            }
            self.lastSequenceTrackers[realmObjectMgr.getObjectType().className()]?.updateLastPushSequence(realm, lastPushSequence: sequence)
        }
    }
    
    func addOrUpdateObjectMapping<T: Object>(realmObjectMgr: RealmObjectManager<T>, realmObject: T, sequence: Int64) {
        let realmDocMaps = self.realm.objects(RealmObjectCouchDBDocMap.self).filter("realmObjectType = '\(realmObjectMgr.getObjectType().className())' AND realmObjectId='\(realmObjectMgr.getObjectId(realmObject))'")
        if (realmDocMaps.count > 0) {
            for realmDocMap in realmDocMaps {
                try! self.realm.write {
                    realmDocMap.couchRev = "1-\(NSUUID().UUIDString)"
                    realmDocMap.couchSequence = sequence
                    self.realm.add(realmDocMap)
                }
            }
        }
        else {
            self.addObjectMapping(realmObjectMgr, realmObject: realmObject, sequence: sequence)
        }
    }
    
    func removeObjectMappings<T: Object>(realmObjectMgr: RealmObjectManager<T>, realmObjects: [T], indexes: [Int]) {
        // TODO: increment sequence?
        //if (indexes.count > 0) {
            //for idx in indexes {
                // TODO: self.removeObjectMapping(realm, realmObjectMgr: realmObjectMgr, realmObject: realmObjects[idx])
            //}
        //}
    }
    
    func removeObjectMapping<T: Object>(realmObjectMgr: RealmObjectManager<T>, realmObject: T) {
        let realmDocMaps = self.realm.objects(RealmObjectCouchDBDocMap.self).filter("realmObjectType = '\(realmObjectMgr.getObjectType().className())' AND realmObjectId='\(realmObjectMgr.getObjectId(realmObject))'")
        if (realmDocMaps.count > 0) {
            for realmDocMap in realmDocMaps {
                // TODO: Need to mark that this has been deleted, so we can delete from server
                try! self.realm.write {
                    self.realm.delete(realmDocMap)
                }
            }
        }
    }
    
    func localChanges<T: Object>(realmObjectMgr: RealmObjectManager<T>, since: Int64, limit: Int32) -> RealmObjectChanges {
        var lastSequence = since
        let realmDocMaps = self.realm.objects(RealmObjectCouchDBDocMap.self).filter("couchSequence > \(lastSequence) AND couchSequence <= \(lastSequence+Int64(limit))")
        if (realmDocMaps.count > 0) {
            for realmDocMap in realmDocMaps {
                lastSequence = max(lastSequence, realmDocMap.couchSequence)
            }
        }
        return RealmObjectChanges(lastSequence: lastSequence, realmDocMaps: Array(realmDocMaps))
    }
    
    func localCheckpoint<T: Object>(realmObjectMgr: RealmObjectManager<T>, replicatorId: String) -> String? {
        return self.lastSequences[realmObjectMgr.getObjectType().className()]!.lastPullSequence
    }
    
    func saveLocalCheckPoint<T: Object>(realmObjectMgr: RealmObjectManager<T>, sequence: String) {
        self.lastSequenceTrackers[realmObjectMgr.getObjectType().className()]?.updateLastPullSequence(realm, lastPullSequence: sequence)
    }
    
    func localRevsDiff<T: Object>(realmObjectMgr: RealmObjectManager<T>, changes: CouchDBChanges) -> [CouchDBBulkDoc] {
        var missingDocs = [CouchDBBulkDoc]()
        var ids = [String]()
        var revs = [String]()
        for changeRow in changes.rows {
            ids.append(changeRow.id)
            revs.append(changeRow.changes[0])
        }
        let predicate = NSPredicate(format:"couchDocId IN %@ AND couchRev IN %@", ids, revs)
        var results = self.realm.objects(RealmObjectCouchDBDocMap.self).filter(predicate)
        var matchingDocIds = [String]()
        for docMap in results {
            matchingDocIds.append(docMap.couchDocId!)
        }
        for changeRow in changes.rows {
            if (matchingDocIds.contains(changeRow.id) == false) {
                missingDocs.append(CouchDBBulkDoc(docRev: CouchDBDocRev(docId: changeRow.id, revision: changeRow.changes[0], deleted: changeRow.deleted), doc:changeRow.doc))
            }
        }
        return missingDocs
    }
    
    func localBulkInsert<T: Object>(realmObjectMgr: RealmObjectManager<T>, docs: [CouchDBBulkDoc]) throws -> Int {
        var changesProcessed = 0
        // stop monitoring changes while we load
        realmObjectMgr.stopMonitoringObjectChanges(self.realm)
        //
        for doc in docs {
            if (doc.docRev.deleted) {
                // TODO:
            }
            else if (doc.doc != nil) {
                var realmObject: T? = nil
                try! self.realm.write {
                    var existingRealmObject = realmObjectMgr.getObjectById(self.realm, id: doc.docRev.docId)
                    if (existingRealmObject != nil) {
                        realmObject = existingRealmObject
                        realmObjectMgr.updateObjectWithDictionary(realmObject!, dict: doc.doc!)
                    }
                    else {
                        realmObject = realmObjectMgr.objectFromDictionary(doc.doc!)
                    }
                    if (realmObject != nil) {
                        changesProcessed += 1
                        self.realm.add(realmObject!)
                    }
                }
                if (realmObject != nil) {
                    self.addOrUpdateObjectMapping(realmObjectMgr, realmObject:realmObject!, sequence: Int64(0))
                }
            }
        }
        // start monitoring changes again
        realmObjectMgr.startMonitoringObjectChanges(self.realm) { (changes) in
            self.processObjectChanges(realmObjectMgr, changes: changes)
        }
        return changesProcessed
    }
    
}

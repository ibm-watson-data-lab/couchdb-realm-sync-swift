//
//  PushReplicator.swift
//  LocationTracker
//
//  Created by Mark Watson on 7/29/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

public class PushReplicator<T: Object> : Replicator {

    var target: CouchDBEndpoint
    var realmObjectMgr: RealmObjectManager<T>
    var replicationMgr: ReplicationManager
    var couchClient: CouchDBClient
    var completionHandler: ((result: ReplicationResult) -> Void)?
    
    public init(target: CouchDBEndpoint, realmObjectMgr: RealmObjectManager<T>, replicationMgr: ReplicationManager) {
        self.target = target
        self.realmObjectMgr = realmObjectMgr
        self.replicationMgr = replicationMgr
        self.couchClient = CouchDBClient(baseUrl: self.target.baseUrl, username: self.target.username, password: self.target.password)
    }
    
    public func getReplicatorId() throws -> String {
        var dict: [String:String] = [String:String]();
        dict["source"] = self.replicationMgr.getRealmObjectReplicatorId(self.realmObjectMgr)
        dict["target"] = self.target.description
        let jsonData = try NSJSONSerialization.dataWithJSONObject(dict, options: [])
        return CryptoUtils.sha1(jsonData)
    }
    
    public func start(completionHandler: (result: ReplicationResult) -> Void) throws {
        self.completionHandler = completionHandler;
        do {
            let replicatorId = try self.getReplicatorId()
            self.couchClient.getCheckpoint(self.target.db, replicationId: replicatorId, completionHandler: { (lastSequence, error) in
                dispatch_async(dispatch_get_main_queue(), {
                    // TODO: implement limit for real
                    let localChanges = try! self.getChanges(lastSequence, limit: Int32.max)
                    // TODO: support filter here
                    // TODO: break this up into batches?
                    let docRevs = self.getDocRevsFromChanges(localChanges)
                    self.couchClient.revsDiff(self.target.db, docRevs: docRevs) { (missingDocRevs, error) in
                        dispatch_async(dispatch_get_main_queue(), {
                            if (error != nil) {
                                self.replicationFailed(error, errorMessage: "Error running revsDiff")
                            }
                            else if (missingDocRevs != nil && missingDocRevs!.count > 0) {
                                let docs = self.getCouchDBBulkDocs(missingDocRevs!, changes:localChanges)
                                self.couchClient.bulkDocs(self.target.db, docs: docs, completionHandler: { (rows, error) in
                                    if (error != nil) {
                                        self.replicationFailed(error, errorMessage: "Error saving checkpoint")
                                    }
                                    else {
                                        self.couchClient.saveCheckpoint(self.target.db, replicationId: replicatorId, lastSequence: localChanges.lastSequence, completionHandler: { (error) in
                                            if (error != nil) {
                                                self.replicationFailed(error, errorMessage: "Error saving checkpoint")
                                            }
                                            else {
                                                self.replicationComplete(missingDocRevs!.count)
                                            }
                                        })
                                    }
                                })
                            }
                            else {
                                self.replicationComplete(0)
                            }
                        })
                    }
                })
            })
        }
        catch {
            self.replicationFailed(error, errorMessage: nil)
        }
    }
    
    private func getChanges(since: Int64?, limit: Int32) throws -> RealmObjectChanges {
        let verifiedSince: Int64 = since ?? 0;
        return self.replicationMgr.localChanges(self.realmObjectMgr, since: verifiedSince, limit: limit)
    }
    
    private func getDocRevsFromChanges(changes: RealmObjectChanges) -> [CouchDBDocRev] {
        var docRevs: [CouchDBDocRev] = []
        for realmDocMap in changes.realmDocMaps {
            docRevs.append(CouchDBDocRev(docId: realmDocMap.couchDocId!, revision: realmDocMap.couchRev!, deleted: false))
        }
        return docRevs
    }
    
    private func getCouchDBBulkDocs(missingDocRevs: [CouchDBDocMissingRevs], changes: RealmObjectChanges) -> [CouchDBBulkDoc] {
        var docs: [CouchDBBulkDoc] = []
        for missingDocRev in missingDocRevs {
            for missingRev in missingDocRev.missingRevs {
                for realmDocMap in changes.realmDocMaps {
                    if (realmDocMap.couchDocId == missingDocRev.docId && realmDocMap.couchRev == missingRev) {
                        let docRev = CouchDBDocRev(docId: realmDocMap.couchDocId!, revision: realmDocMap.couchRev!, deleted: false)
                        //let revisions = CouchDBBulkDocRev(start: 1, ids: [missingRev])
                        let doc = self.realmObjectToDictionary(realmDocMap.realmObjectId!)
                        if (doc != nil) {
                            //docs.append(CouchDBBulkDoc(docRev: docRev, revisions: revisions, doc: doc))
                            docs.append(CouchDBBulkDoc(docRev: docRev, doc: doc))
                        }
                    }
                }
            }
        }
        return docs
    }
    
    private func realmObjectToDictionary(realmObjectId: String) -> [String:AnyObject]? {
        let objects = self.realmObjectMgr.getObjectsMatchingIds(self.replicationMgr.realm, ids: [realmObjectId])
        if (objects.count > 0) {
            return self.realmObjectMgr.objectToDictionary(objects[0])
        }
        else {
            return nil
        }
    }
    
    // MARK: Replication Complete/Cancel Functions
    
    private func replicationComplete(changesProcessed: Int) {
        self.completionHandler?(result: ReplicationResult(replicator: self, changesProcessed: changesProcessed))
    }
    
    private func replicationFailed(error: ErrorType?, errorMessage: String?) {
        self.completionHandler?(result: ReplicationResult(replicator: self, error: error, errorMessage: errorMessage))
    }
}

//
//  RealmCloudantPullReplicator.swift
//  LocationTracker
//
//  Created by Mark Watson on 7/29/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

public class PullReplicator<T: Object> : Replicator {
    
    var source: CouchDBEndpoint
    var realmObjectMgr: RealmObjectManager<T>
    var replicationMgr: ReplicationManager
    var couchClient: CouchDBClient
    var completionHandler: ((result: ReplicationResult) -> Void)?
    
    public init(source: CouchDBEndpoint, realmObjectMgr: RealmObjectManager<T>, replicationMgr: ReplicationManager) {
        self.source = source
        self.realmObjectMgr = realmObjectMgr
        self.replicationMgr = replicationMgr
        self.couchClient = CouchDBClient(baseUrl: self.source.baseUrl, username: self.source.username, password: self.source.password)
    }
    
    public func getReplicatorId() throws -> String {
        var dict: [String:String] = [String:String]();
        dict["source"] = self.source.description
        dict["target"] = self.replicationMgr.getRealmObjectReplicatorId(self.realmObjectMgr)
        let jsonData = try NSJSONSerialization.dataWithJSONObject(dict, options: [])
        return CryptoUtils.sha1(jsonData)
    }
    
    public func start(completionHandler: (result: ReplicationResult) -> Void) throws {
        self.completionHandler = completionHandler
        let replicatorId = try self.getReplicatorId()
        print("REPLICATOR ID: \(replicatorId)")
        let checkpoint = self.replicationMgr.localCheckpoint(self.realmObjectMgr, replicatorId: replicatorId)
        self.couchClient.getChanges(self.source.db, since: checkpoint, includeDocs: true) { (changes, error) in
            dispatch_async(dispatch_get_main_queue(), {
                if (error != nil) {
                    self.replicationFailed(error, errorMessage: "Error getting changes from CouchDB")
                }
                else if (changes == nil) {
                    self.replicationComplete(0)
                }
                else {
                    let missingDocs = self.replicationMgr.localRevsDiff(self.realmObjectMgr, changes: changes!)
                    if (missingDocs.count > 0) {
                        do {
                            let changesProcessed = try self.replicationMgr.localBulkInsert(self.realmObjectMgr, docs: missingDocs)
                            self.replicationMgr.saveLocalCheckPoint(self.realmObjectMgr, sequence: changes!.lastSequence!)
                            self.replicationComplete(changesProcessed)
                        }
                        catch {
                            self.replicationFailed(error, errorMessage: "Error updating documents")
                        }
                    }
                }
            })
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

//
//  IdFieldRealmObjectReplication.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/2/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

public class RealmObjectManager<T: Object> {
    
    var idField: String
    var type: T.Type
    private var notificationToken: NotificationToken?
    
    public init(idField: String, type: T.Type) {
        self.idField = idField
        self.type = type
    }
    
    public func getObjectType() -> T.Type {
        return self.type
    }
    
    public func getObjectId(object: T) -> String {
        return object[self.idField] as! String
    }
    
    public func getObjectById(realm: Realm, id: String) -> T? {
        let clause = "\(self.idField) = %@"
        let predicate = NSPredicate(format: clause, id)
        let results = realm.objects(T).filter(predicate)
        if (results.count == 0) {
            return nil
        }
        else {
            return results[0]
        }
    }
    
    public func getObjectsMatchingIds(realm: Realm, ids: [String]) -> Results<T> {
        let clause = "\(self.idField) IN %@"
        let predicate = NSPredicate(format: clause, ids)
        return realm.objects(T).filter(predicate)
    }
    
    public func getObjectsNotMatchingIds(realm: Realm, ids: [String]) -> Results<T> {
        if (ids.count == 0) {
            return realm.objects(T)
        }
        else {
            let clause = "NOT (\(self.idField) IN %@)"
            let predicate = NSPredicate(format: clause, ids)
            return realm.objects(T).filter(predicate)
        }
    }
    
    public func objectToDictionary(object: T) -> [String:AnyObject] {
        return object.toDictionary()
    }
    
    public func objectFromDictionary(dict: [String:AnyObject]) -> T? {
        let object = Object.objectClassFromString(self.type.className()) as? T
        if (object != nil) {
            self.updateObjectWithDictionary(object!, dict: dict)
            return object
        }
        else {
            return nil
        }
    }
    
    public func updateObjectWithDictionary(object: T, dict: [String:AnyObject]) {
        object.updateFromDictionary(dict)
    }
    
    public func startMonitoringObjectChanges(realm: Realm, completionHandler: (changes: RealmCollectionChange<Results<T>>) -> Void) {
        self.notificationToken = realm.objects(T).addNotificationBlock { (changes) in
            completionHandler(changes: changes)
        }
    }
    
    public func stopMonitoringObjectChanges(realm: Realm) {
        if (self.notificationToken != nil) {
            self.notificationToken?.stop()
            self.notificationToken = nil
        }
    }
}
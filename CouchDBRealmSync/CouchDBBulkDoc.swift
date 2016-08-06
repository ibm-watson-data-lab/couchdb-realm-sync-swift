//
//  CouchDBBulkDoc.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation

public class CouchDBBulkDoc {
    
    //  {
    //    _id: XXX,
    //    _rev: 1-YYY,
    //    customProperty: 123,
    //    _revisions: {
    //      start: 1,
    //      ids: [YYY]
    //    }
    //  }
    
    var docRev: CouchDBDocRev
    //var revisions: CouchDBBulkDocRev
    var doc: [String:AnyObject]?
    
//    public init(docRev: CouchDBDocRev, revisions:CouchDBBulkDocRev, doc: [String:AnyObject]?) {
//        self.docRev = docRev
//        self.revisions = revisions
//        self.doc = doc
//    }
    
    public init(docRev: CouchDBDocRev, doc: [String:AnyObject]?) {
        self.docRev = docRev
        self.doc = doc
    }
    
    func toDictionary() -> [String:AnyObject] {
        var dict:[String:AnyObject] = [String:AnyObject]();
        dict["_id"] = self.docRev.docId
        dict["_rev"] = self.docRev.revision
        // TODO: this is not set up properly right now - not sure if even required
        //dict["_revisions"] = self.revisions.toDictionary()
        if (self.doc != nil) {
            for key in self.doc!.keys {
                if (dict[key] != nil) {
                    dict["_\(key)"] = self.doc![key]
                }
                else {
                    dict[key] = self.doc![key]
                }
            }
        }
        return dict
    }
}

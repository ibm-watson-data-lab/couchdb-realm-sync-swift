//
//  CouchDBBulkDocsReq.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation

public class CouchDBBulkDocsReq {

    //    new_edits: false,
    //    docs: [{
    //      _id: XXX,
    //      _rev: 1-YYY,
    //      customProperty: 123,
    //      _revisions: {
    //        start: 1,
    //        ids: [YYY]
    //      }
    //    }]

    var docs: [CouchDBBulkDoc]
    
    public init(docs:[CouchDBBulkDoc]) {
        self.docs = docs
    }
    
    func toDictionary() -> [String:AnyObject] {
        var docDicts: [[String:AnyObject]] = []
        for doc in self.docs {
            docDicts.append(doc.toDictionary())
        }
        var dict:[String:AnyObject] = [String:AnyObject]();
        dict["new_edits"] = false
        dict["docs"] = docDicts
        return dict
    }
    

}

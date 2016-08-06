//
//  DocumentRevision.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/2/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation

public class CouchDBDocRev {
    
    var docId: String
    var revision: String
    var deleted: Bool
    
    init(docId: String, revision: String, deleted: Bool) {
        self.docId = docId;
        self.revision = revision
        self.deleted = deleted
    }
}

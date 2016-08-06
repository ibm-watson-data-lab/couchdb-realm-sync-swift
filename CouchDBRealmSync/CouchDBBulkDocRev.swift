//
//  CouchDBBulkDocRev.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation

public class CouchDBBulkDocRev {
    
    //  {
    //    start: 1,
    //    ids: [YYY]
    //  }
    
    var start: Int64
    var ids: [String]
    
    public init(start:Int64, ids: [String]) {
        self.start = start
        self.ids = ids
    }
    
    func toDictionary() -> [String:AnyObject] {
        var dict:[String:AnyObject] = [String:AnyObject]();
        dict["start"] = NSNumber(longLong:self.start)
        dict["ids"] = self.ids
        return dict
    }
}

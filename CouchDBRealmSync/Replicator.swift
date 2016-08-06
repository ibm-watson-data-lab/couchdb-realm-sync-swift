//
//  Replicator.swift
//  LocationTracker
//
//  Created by Mark Watson on 7/28/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Foundation

public protocol Replicator: AnyObject {
    func start(completionHandler: (result: ReplicationResult) -> Void) throws
}

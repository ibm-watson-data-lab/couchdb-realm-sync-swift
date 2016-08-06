//
//  CouchDBClient.swift
//  LocationTracker
//
//  Created by Mark Watson on 7/29/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Foundation

public enum CouchDBError: ErrorType {
    case EmptyResponse
}

public class CouchDBClient {
    
    var baseUrl: String
    var username: String?
    var password: String?
    
    public init(baseUrl: String) {
        self.baseUrl = baseUrl
    }
    
    public init(baseUrl: String, username: String?, password: String?) {
        self.baseUrl = baseUrl
        self.username = username
        self.password = password
    }
    
    // MARK: _all_docs
    
    public func getAllDocs(db: String, completionHandler: (rows: [AnyObject]?, error: ErrorType?) -> Void) {
        let session = NSURLSession.sharedSession()
        let request = self.createGetRequest(db, path: "_all_docs")
        let task = session.dataTaskWithRequest(request) {
            (let data, let response, let err) in
            do {
                let dict: NSDictionary? = try self.parseResponse(data, response: response, error: err)
                if (dict != nil) {
                    if let rows = dict!["rows"] as? [[String:AnyObject]] {
                        completionHandler(rows: rows, error: nil)
                    }
                    else {
                        completionHandler(rows: nil, error: nil)
                    }
                }
                else {
                    completionHandler(rows: nil, error: nil)
                }
            }
            catch {
                completionHandler(rows: nil, error: error)
            }
        }
        task.resume()
    }
    
    // MARK: _bulk_docs
    
    public func bulkDocs(db: String, docs: [CouchDBBulkDoc], completionHandler: (docs: [AnyObject]?, error: ErrorType?) -> Void) {
         do {
            let bulkDocRequest = CouchDBBulkDocsReq(docs: docs)
            let body = try NSJSONSerialization.dataWithJSONObject(bulkDocRequest.toDictionary(), options: [])
            let session = NSURLSession.sharedSession()
            let request = self.createPostRequest(db, path: "_bulk_docs", body: body)
            let task = session.dataTaskWithRequest(request) {
                (let data, let response, let err) in
                do {
                    let array: [AnyObject]? = try self.parseResponseAsArray(data, response: response, error: err)
                    if (array != nil) {
                        completionHandler(docs: array, error: nil)
                    }
                    else {
                        completionHandler(docs: nil, error: nil)
                    }
                }
                catch {
                    completionHandler(docs: nil, error: error)
                }
            }
            task.resume()
         }
         catch {
            completionHandler(docs: nil, error: error)
        }
    }
    
    // MARK: _changes
    
    public func getChanges(db: String, since: String?, includeDocs: Bool, completionHandler: (changes: CouchDBChanges?, error: ErrorType?) -> Void) {
        var path = "_changes?include_docs=\(includeDocs)"
        if (since != nil) {
            path = "\(path)&since=\(since!)"
        }
        let session = NSURLSession.sharedSession()
        let request = self.createGetRequest(db, path: path)
        let task = session.dataTaskWithRequest(request) {
            (let data, let response, let err) in
            do {
                let dict: [String:AnyObject]? = try self.parseResponse(data, response: response, error: err)
                if (dict != nil) {
                    completionHandler(changes: CouchDBChanges(dict: dict!), error: nil)
                }
                else {
                    completionHandler(changes: nil, error: nil)
                }
            }
            catch {
                completionHandler(changes: nil, error: error)
            }
        }
        task.resume()
    }
    
    // MARK: _local
    
    public func saveCheckpoint(db: String, replicationId: String, lastSequence: Int64, completionHandler: (error: ErrorType?) -> Void) {
        do {
            let body = try NSJSONSerialization.dataWithJSONObject(["lastSequence":"\(lastSequence)"], options: [])
            let session = NSURLSession.sharedSession()
            let request = self.createPutRequest(db, path: "_local/\(replicationId)", body: body)
            let task = session.dataTaskWithRequest(request) {
                (let data, let response, let err) in
                do {
                    let dict: NSDictionary? = try self.parseResponse(data, response: response, error: err)
                    if (dict != nil) {
                        print("SAVE CHECKPOINT RESPONSE: \(dict!)")
                        completionHandler(error: nil)
                    }
                    else {
                        completionHandler(error: nil)
                    }
                }
                catch {
                    completionHandler(error: error)
                }
            }
            task.resume()
        }
        catch {
            completionHandler(error: error)
        }
    }
    
    public func getCheckpoint(db: String, replicationId: String, completionHandler: (lastSequence: Int64?, error: ErrorType?) -> Void) {
        let session = NSURLSession.sharedSession()
        let request = self.createGetRequest(db, path: "_local/\(replicationId)")
        let task = session.dataTaskWithRequest(request) {
            (let data, let response, let err) in
            do {
                let dict: NSDictionary? = try self.parseResponse(data, response: response, error: err)
                if (dict != nil) {
                    print("GET CHECKPOINT RESPONSE: \(dict!)")
                    let lastSequence: Int64? = dict!["lastSequence"]?.longLongValue
                    completionHandler(lastSequence: lastSequence, error: nil)
                }
                else {
                    completionHandler(lastSequence: nil, error: nil)
                }
            }
            catch {
                completionHandler(lastSequence: nil, error: error)
            }
        }
        task.resume()
    }
    
    // MARK: _revs_diff
    
    public func revsDiff(db: String, docRevs: [CouchDBDocRev], completionHandler: (missingDocRevs: [CouchDBDocMissingRevs]?, error: ErrorType?) -> Void) {
        do {
            var dict = [String:[String]]()
            for docRev in docRevs {
                dict[docRev.docId] = [docRev.revision]
            }
            let body = try NSJSONSerialization.dataWithJSONObject(dict, options: [])
            let session = NSURLSession.sharedSession()
            let request = self.createPostRequest(db, path: "_revs_diff", body: body)
            let task = session.dataTaskWithRequest(request) {
                (let data, let response, let err) in
                do {
                    let dict: NSDictionary? = try self.parseResponse(data, response: response, error: err)
                    if (dict != nil) {
                        var docMissingRevs: [CouchDBDocMissingRevs] = []
                        for key in dict!.allKeys {
                            let missingRevs = (dict?.objectForKey(key) as! NSDictionary).objectForKey("missing") as! [String]
                            docMissingRevs.append(CouchDBDocMissingRevs(docId: key as! String, missingRevs: missingRevs))
                        }
                        completionHandler(missingDocRevs: docMissingRevs, error: nil)
                    }
                    else {
                        completionHandler(missingDocRevs: [], error: nil)
                    }
                }
                catch {
                    completionHandler(missingDocRevs: nil, error: error)
                }
            }
            task.resume()
        }
        catch {
            completionHandler(missingDocRevs: nil, error: error)
        }
    }
    
    // MARK: Helper Functions
    
    func createGetRequest(db: String, path: String) -> NSMutableURLRequest {
        let url = NSURL(string: "\(self.baseUrl)/\(db)/\(path)")
        let request = NSMutableURLRequest(URL: url!)
        request.addValue("application/json", forHTTPHeaderField:"Content-Type")
        request.addValue("application/json", forHTTPHeaderField:"Accepts")
        request.HTTPMethod = "GET"
        if (self.username != nil && self.password != nil) {
            let loginString = "\(self.username!):\(self.password!)"
            let loginData: NSData? = loginString.dataUsingEncoding(NSUTF8StringEncoding)
            let base64LoginString = loginData!.base64EncodedStringWithOptions(.Encoding64CharacterLineLength)
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    func createPostRequest(db: String, path: String, body: NSData?) -> NSMutableURLRequest {
        let url = NSURL(string: "\(self.baseUrl)/\(db)/\(path)")
        let request = NSMutableURLRequest(URL: url!)
        request.addValue("application/json", forHTTPHeaderField:"Content-Type")
        request.addValue("application/json", forHTTPHeaderField:"Accepts")
        request.HTTPMethod = "POST"
        if (body != nil) {
            request.HTTPBody = body
        }
        return request
    }
    
    func createPutRequest(db: String, path: String, body: NSData?) -> NSMutableURLRequest {
        let url = NSURL(string: "\(self.baseUrl)/\(db)/\(path)")
        let request = NSMutableURLRequest(URL: url!)
        request.addValue("application/json", forHTTPHeaderField:"Content-Type")
        request.addValue("application/json", forHTTPHeaderField:"Accepts")
        request.HTTPMethod = "PUT"
        if (body != nil) {
            request.HTTPBody = body
        }
        return request
    }
    
    func parseResponse(data:NSData?, response:NSURLResponse?, error:NSError?) throws -> [String:AnyObject]? {
        if (error != nil) {
            throw error!
        }
        else if (data == nil) {
            throw CouchDBError.EmptyResponse
        }
        return try NSJSONSerialization.JSONObjectWithData(data!, options:[]) as? [String:AnyObject]
    }
    
    func parseResponseAsArray(data:NSData?, response:NSURLResponse?, error:NSError?) throws -> [AnyObject]? {
        if (error != nil) {
            throw error!
        }
        else if (data == nil) {
            throw CouchDBError.EmptyResponse
        }
        return try NSJSONSerialization.JSONObjectWithData(data!, options:[]) as? [AnyObject]
    }
    
}
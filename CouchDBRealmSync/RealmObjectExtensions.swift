//
//  RealmObjectExtensions.swift
//  CouchDBRealmSync
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 IBM CDS Labs. All rights reserved.
//

import Foundation
import Realm
import RealmSwift

extension Object {
    
    func toDictionary() -> [String:AnyObject] {
        let properties = self.objectSchema.properties.map { $0.name }
        let dictionary = self.dictionaryWithValuesForKeys(properties)
        
        let mutabledic = NSMutableDictionary()
        mutabledic.setValuesForKeysWithDictionary(dictionary)
        
        for prop in self.objectSchema.properties as [Property]! {
            // find lists
            if let nestedObject = self[prop.name] as? Object {
                mutabledic.setValue(nestedObject.toDictionary(), forKey: prop.name)
            } else if let nestedListObject = self[prop.name] as? ListBase {
                var objects = [AnyObject]()
                for index in 0..<nestedListObject._rlmArray.count  {
                    let object = nestedListObject._rlmArray[index] as AnyObject
                    objects.append(object.toDictionary())
                }
                mutabledic.setObject(objects, forKey: prop.name)
            }
            
        }
        
        var dict = [String:AnyObject]()
        for key in mutabledic.allKeys {
            if let keyStr = key as? String {
                dict[keyStr] = mutabledic.objectForKey(keyStr)
            }
        }
        return dict
    }
    
    func updateFromDictionary(dict: [String:AnyObject]) {
        let primaryKey = self.dynamicType.primaryKey()
        var primaryKeyExists = false
        if (primaryKey != nil) {
            primaryKeyExists = (self.valueForKey(primaryKey!) != nil)
        }
        for prop in self.objectSchema.properties as [Property]! {
            if let value = dict[prop.name] {
                if let nestedObjectDict = value as? [String:AnyObject] {
                    var nestedObjectIsNew = false
                    var nestedObject = self[prop.name] as? Object
                    if (nestedObject == nil && prop.objectClassName != nil) {
                        nestedObject = Object.objectClassFromString(prop.objectClassName!)
                        nestedObjectIsNew = true
                    }
                    if (nestedObject != nil) {
                        nestedObject!.updateFromDictionary(nestedObjectDict)
                        if (nestedObjectIsNew) {
                            self.setValue(nestedObject, forKey: prop.name)
                        }
                    }
                }
//                else if let nestedObjectArray = value as? [[AnyObject]] {
//                    // TODO:
//                }
                else {
                    if (prop.name == primaryKey) {
                        if (primaryKeyExists == false) {
                            primaryKeyExists = true
                            self.setValue(value, forKey: prop.name)
                        }
                    }
                    else {
                        self.setValue(value, forKey: prop.name)
                    }
                }
            }
        }
    }
    
    class func objectClassFromString(className: String) -> Object? {
        var clazz = NSClassFromString(className) as? Object.Type
        if (clazz == nil) {
            // get the project name
            if  let appName: String? = NSBundle.mainBundle().infoDictionary!["CFBundleName"] as? String {
                let classStringName = "\(appName!).\(className)"
                clazz = NSClassFromString(classStringName) as? Object.Type
            }
        }
        if (clazz != nil) {
            return clazz!.init()
        }
        else {
            return nil
        }
    }
    
}
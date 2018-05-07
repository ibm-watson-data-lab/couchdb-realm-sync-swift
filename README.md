:no_entry_sign: This project is no longer maintained

# CouchDB Realm Sync Library

This is an Experimental Swift library for syncing data between local Realm datastores and CouchDB.

Use with caution!

## Quick Start Using CocoaPods

Add CouchDBRealmSync to your Podfile and install:

```
pod "CouchDBRealmSync", :git => "https://github.com/ibm-cds-labs/couchdb-realm-sync-swift.git"
pod install
```

Sync your Realm objects with just a few lines of code:

```
import CouchDBRealmSync

let replicationManager = ReplicationManager(realm: realm!)

replicationManager.register(Dog.self)

let dogsEndpoint = CouchDBEndpoint(baseUrl: "https://couchdbhost:port", username: "user", password: "pwd", db: "dogs")

replicationManager.pull(dogsEndpoint, target: Dog.self).start({ (result) in
})

replicationManager.push(Dog.self, target: dogsEndpoint).start({ (result) in
})
```

## Breakdown

Import CouchDBRealmSync in your Realm app:

```
import CouchDBRealmSync
```

Create and initialize a replication manager with your Realm instance:

```
var replicationManager = ReplicationManager(realm: realm!)
```

Register your Realm objects with the replication manager:

```
replicationManager.register(Dog.self)
```

Note: this method of registering Realm objects requires that your objects expose a primary key field using Realm's class `primaryKey()` function.
If your existing Realm objects do not override this function and you cannot change your Realm objects you need to create or extend `RealmObjectManager` and register that with the replication manager.
See below for more details.

Create a CouchDB endpoint:

```
let dogsEndpoint = CouchDBEndpoint(baseUrl: "https://couchdbhost:port", username: "user", password: "pwd", db: "dogs")
```

To pull data from CouchDB into your local Realm datastore run pull on the replication manager:

```
replicationManager.pull(dogsEndpoint, target: Dog.self).start({ (result) in
	// see ReplicationResult
})
```

To push data from your local Realm datastore to CouchDB run push on the replication manager:

```
replicationManager.push(Dog.self, target: dogsEndpoint).start({ (result) in
	// see ReplicationResult
})
```

## Example

See the [Realm version of the Location Tracker app](https://github.com/ibm-cds-labs/location-tracker-client-swift-realm). The Location Tracker app stores and syncs location information with IBM Cloudant.

## How it works

Realm data models are simply Swift classes that extend the Realm Object class. For example:

```
import RealmSwift

// Dog model
class Dog: Object {
   dynamic var name = ""
   dynamic var owner: Person? // Properties can be optional
}
```

The Realm API is easy and straight forward. To create a Dog and save it:

```
let realm = try! Realm()
try! realm.write() {
   var dog = Dog()
   dog.name = "Dogbert"
   realm.addObject(dog)
}
```

To get a list of Dogs:

```
let dogs = realm.objects(Dog.self)
```

To support replication we need to map Realm objects to CouchDB documents,
which means we need a unique doc id, a revision #, and other sync related metadata.

Adding new properties to Realm objects requires migration.
Requiring users to extend their Realm objects to include these properties is not ideal,
so the CouchDBRealmSync library currently works like this:

1. The library itself uses Realm to store mappings between the CouchDB doc and the Realm object. The mapping includes the Realm object Id, CouchDB doc id (which maybe should be the same, but currently is not), CouchDB revision, sequence (to keep track of replication state), and a deleted Bool.
2. The library subscribes to all Realm object changes (https://realm.io/news/marin-todorov-fine-grained-notifications/). When a new Realm object is created on the device the library creates a corresponding mapping object, generates a doc id and revision, increments the sequence, etc.
3. When it comes time to push objects from the device to the server the library implements a variation of the standard replication protocol (some features missing) which retrieves a checkpoint from the server, finds any objects created after that checkpoint (using the mapping tables), performs a bulk_docs operation, and finally updates the checkpoint on the server.
4. During a pull replication the library again implements a variation of the standard replication protocol which queries the device for the last pull checkpoint, calls changes on the server using that checkpoint (right now it only gets the winning rev),  compares the doc ids returned in the list to what is store locally (deletes are not currently supported), adds or updates any realm object, adds or updates the map object (revision, sequence, etc), and finally saves the local checkpoint. It is important to note that Realm notifications are turned off during this time as we don’t want to mistake a document being inserted/updated in Realm as a local insert/edit.

The library also provides integration points for modifying the data as it goes from Realm to CouchDB and back. For example, in the Location Tracker a LocationObject (Realm) looks like this:

```
class LocationObject: Object {

   dynamic var docId: String?
   dynamic var timestamp: Double = 0
   dynamic var geometry: Geometry?
   dynamic var properties: LocationProperties?
   dynamic var type = "Feature"

   // ...
}
```

If we sync this to CouchDB without modifying the data we will get a document that looks like this:

```
{
  "_id": "2136FAA5-B682-4EB8-A176-E649DFE6A4BF",
  "_rev": "1-64FFEF17-FFF4-4594-AEC5-D9873892BE22",
  "type": "Feature",
  "properties": {
    "background": false,
    "timestamp": 1470337737739.341,
    "username": "envoy_user1"
  },
  "timestamp": 1470337737739.341,
  "geometry": {
    "longitude": -122.22359156,
    "latitude": 37.42079209
  },
  "docId": "C43B6B59-B72D-4EDA-A066-8A17E3905EDE"
}
```

This works fine, but the document doesn't conform to the GeoJSON spec, so Cloudant can't index it.
The CouchDBRealmSync library has the concept of a "RealmObjectManager".
We can create custom RealmObjectManagers that have more control over the format sent to CouchDB (and a few other things).
Without an object manager you register your intent to sync a Realm collection as so:

```
replicationManager.register(LocationObject.self)
```

If you create a custom RealmObjectManager, for example `LocationObjectManager` you register like so:

```
replicationManager.register(LocationObjectManager())
```

LocationObjectManager looks something like this:

```
class LocationObjectManager: RealmObjectManager<LocationObject> {

   init() {
      super.init(idField:"docId", type:LocationObject.self)
   }

   override func objectToDictionary(object: LocationObject) -> [String:AnyObject] {
      var dict:[String:AnyObject] = [String:AnyObject]();
      dict["type"] = "Feature"
      dict["created_at"] = object.timestamp
      dict["geometry"] = self.geometryToDictionary(object.geometry)
      dict["properties"] = self.propertiesToDictionary(object.properties)
      return dict
   }

   override func objectFromDictionary(dict: [String:AnyObject]) -> LocationObject {
      // create local LocationObject from CouchDB doc
   }

   override func updateObjectWithDictionary(object: LocationObject, dict: [String : AnyObject]) {
      // update local LocationObject from CouchDB doc
   }
}
```

Now when we sync a LocationObject it looks like this in Cloudant and geo indexes work:

```
{
  "_id": "A5614053-5085-46AA-8BF2-D4C19DE51F50",
  "_rev": "1-85B0570A-5638-440A-8BF9-14F7C6268264",
  "created_at": 1470338317296.108,
  "type": "Feature",
  "properties": {
    "timestamp": 1470338317296.108,
    "background": false,
    "username": "envoy_user1"
  },
  "geometry": {
    "coordinates": [
      -122.22651609,
      37.4228281
    ],
    "type": "Point"
  }
}
```

## Known Limitations

Use this library with caution. It is still very experimental and has the following known limitations:

1. Deletes are not supported.
2. Conflict resolution has not been implemented.
3. During a pull or push replication all documents are processed at once (not in batches like other sync libraries).
4. Threading restrictions - right now we require that the Realm be created in the main thread.
5. Testing - There has been very little testing and no unit tests have been written.

## License

Licensed under the [Apache License, Version 2.0](LICENSE.txt).

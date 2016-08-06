Pod::Spec.new do |s|
  s.name         = "CouchDBRealmSync"
  s.version      = "0.0.1"
  s.summary      = "Experimental Swift library for syncing data between local Realm datastores and CouchDB."
  s.description  = "Experimental Swift library for syncing data between local Realm datastores and CouchDB. CouchDBRealmSync provides a simple API that integrates with your existing apps and requires no changes to your Realm Objects."
  s.homepage     = "https://github.com/ibm-cds-labs/couchdb-realm-sync-swift"
  s.license      = "MIT"
  s.author       = { "" => "markwats@us.ibm.com" }
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/ibm-cds-labs/couchdb-realm-sync-swift.git", :tag => "#{s.version}" }
  s.source_files = "CouchDBRealmSync/**/*.{swift}" 
  s.dependency "CryptoSwift", '~> 0.4.1'
  s.dependency "RealmSwift", '~> 0.103.0'
end
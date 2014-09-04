//
//  CloudKitQueriable.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 7/25/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import CloudKit

public class CloudKitQueriable: DebugPrintable, Hashable {
    let recordID: CKRecordID
    
    public var debugDescription: String {
        get {
            return "CloudKitQueriable = {recordID: \(recordID), fetched: \(fetched())}"
        }
    }
    
    public var hashValue: Int {
        get {
            return recordID.hashValue
        }
    }
    
    public func fetched() -> Bool {
        return false
    }
    
    public class func allFetched(models: [CloudKitQueriable]) -> Bool {
        for model in models {
            if !model.fetched() {
                return false
            }
        }
        return true
    }
    
    public init(recordID: CKRecordID) {
        self.recordID = recordID
    }
    
    public init(record: CKRecord) {
        self.recordID = record.recordID
        fatalError("init(record:) must be overridden")
    }
    
    public func fetchWithCompletion(completion: (error: NSError?) -> Void) {
        fetchWithOption(.FetchNonRelationalProperties, completion: completion)
    }
    
    public func fetchWithOption(fetchOption: FetchModelOption, completion: (error: NSError?) -> Void) {
        CloudKitManager.sharedManager.fetchAllPropertiesInModel(self, fetchOption: fetchOption, completion: completion)
    }

}

public func == <T: CloudKitQueriable, U: CloudKitQueriable>(lhs: T , rhs: U) -> Bool {
    return lhs.recordID == rhs.recordID
}

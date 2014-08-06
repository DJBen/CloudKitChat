//
//  CloudKitQueriable.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 7/25/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import CloudKit

public class CloudKitQueriable: Equatable, DebugPrintable {
    let recordID: CKRecordID
    public var debugDescription: String {
        get {
            return "CloudKitQueriable = {recordID: \(recordID), fetched: \(fetched())}"
        }
    }
    
    public func fetched() -> Bool {
        return false
    }
    
    public init(recordID: CKRecordID) {
        self.recordID = recordID
    }
    
    public init(record: CKRecord) {
        self.recordID = record.recordID
        fatalError("init(record:) must be overridden")
    }
    
    public func fetchWithCompletion(completion: (error: NSError?) -> Void) {
        CloudKitManager().fetchAllPropertiesInModel(self, completion: completion)
    }
    
}

public func == <T: CloudKitQueriable, U: CloudKitQueriable>(lhs: T , rhs: U) -> Bool {
    return lhs.recordID == rhs.recordID
}
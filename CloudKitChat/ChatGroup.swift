//
//  ChatGroup.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 7/23/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit
import CloudKit

let ChatGroupRecordType: String = "ChatGroup"
let ChatGroupNameKey = "name"
let ChatGroupPeopleKey = "people"
let ChatGroupMessagesKey = "messages"
let ChatGroupOwnerKey = "owner"

// TODO: Greet Realm
public class ChatGroup: CloudKitQueriable, Hashable {
    public var name: String?
    public var owner: User?
    public var people: [User]?
    public var messages: [Message]?
    public var lastMessage: Message? {
        get {
            if messages != nil || messages!.count == 0 {
                return nil
            }
            return messages![messages!.count - 1]
        }
    }
    
    public var hashValue: Int {
        get {
            return self.recordID.hash
        }
    }
    
    public override var debugDescription: String {
        get {
            let peopleCount = people?.count ?? -1
            let messageCount = messages?.count ?? -1
            return "ChatGroup = {recordID: \(recordID.recordName), fetched: \(fetched()), name: \(name), owner: \(owner), #people: \(peopleCount), #messages: \(messageCount)}"
        }
    }
    
    public override init(recordID: CKRecordID) {
        super.init(recordID: recordID)
    }
    
    public convenience init(recordID: CKRecordID, name: String?, owner: User?, people: [User]?, messages: [Message]?) {
        self.init(recordID: recordID)
        self.people = people;
        self.messages = messages
        self.name = name
        self.owner = owner;
    }
    
    public override convenience init(record: CKRecord) {
        if record.recordType != ChatGroupRecordType {
            fatalError("Type mismatch: CKRecord's recordType must fit class' type")
        }
        self.init(recordID: record.recordID)
        if let name = record.objectForKey(ChatGroupNameKey) as? String {
            self.name = name
        }
        if let ownerReference = record.objectForKey(ChatGroupOwnerKey) as? CKReference {
            self.owner = User(recordID: ownerReference.recordID)
        }
        if let peopleReferences = record.objectForKey(ChatGroupPeopleKey) as? [CKReference] {
            self.people = peopleReferences.map {
                personReference -> User in
                return User(recordID: personReference.recordID)
            }
        }
        if let messageReferences = record.objectForKey(ChatGroupMessagesKey) as? [CKReference] {
            self.messages = messageReferences.map {
                messageReference -> Message in
                return Message(recordID: messageReference.recordID)
            }
        }
    }
    
    // MARK: Public Properties
    override public func fetched() -> Bool  {
        return self.messages != nil && self.name != nil && self.people != nil && self.owner != nil
    }
    
    public func fetchMessages(completion: (messages: [Message]?, error: NSError?) -> Void) {
        CloudKitManager.sharedManager.fetchMessagesInChatGroup(self, messageLimit: nil, completion: completion)
    }
    
}

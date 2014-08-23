//
//  User.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 7/23/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit
import CloudKit

let UserRecordType: String = CKRecordTypeUserRecord
let UserNameKey = "name"
let UserChatGroupsKey = "groups" // derived

// TODO: NSObject should be changed to RLMObject
public class User: CloudKitQueriable {
    public var name: String?
    public var chatGroups: [ChatGroup]?
    public var profilePicture: UIImage?
    
    public override var debugDescription: String {
        get {
            var chatGroupCountString: String = String()
            if chatGroups != nil {
                chatGroupCountString = ", #chatGroups: \(chatGroups!.count)"
            }
            return "User = {recordID: \(recordID.recordName), fetched: \(fetched()), name: \(name)\(chatGroupCountString)}"
        }
    }
    
    public override init(recordID: CKRecordID)  {
        super.init(recordID: recordID)
    }
    
    public convenience init(recordID: CKRecordID, name: String?, chatGroups: [ChatGroup]?) {
        self.init(recordID: recordID)
        self.chatGroups = chatGroups
        self.name = name
    }
    
    public convenience override init(record: CKRecord) {
        if record.recordType != UserRecordType {
            fatalError("Type mismatch: CKRecord's recordType must fit class' type")
        }
        self.init(recordID: record.recordID)
        if let name = record.objectForKey(UserNameKey) as? String {
            self.name = name
        }
        if let chatGroupsReference = record.objectForKey(UserChatGroupsKey) as? [CKReference] {
            self.chatGroups = chatGroupsReference.map {
                chatGroupReference -> ChatGroup in
                return ChatGroup(recordID: chatGroupReference.recordID)
            }
        } else {
            self.chatGroups = [ChatGroup]()
        }
    }
    
    public override func fetched() -> Bool {
        return self.chatGroups != nil && self.name != nil
    }
    
    public class func setName(name: String, completion: (error: NSError?) -> Void) {
        CloudKitManager.sharedManager.setUserName(name, completion: completion)
    }
    
    public class func fetchUserWithNameDiscovered(discoverName: Bool, completion: FetchUserCompletionBlock) {
        CloudKitManager.sharedManager.fetchUserWithNameDiscovered(discoverName, completion: completion)
    }
    
    public func fetchChatGroupsWithCompletion(completion: (chatGroups: [ChatGroup]?, error: NSError?) -> Void) {
        CloudKitManager.sharedManager.fetchChatGroupsForUser(self, completion: completion)
    }
    
    public func fetchChatGroupsWithFullDetails(includeDetails: Bool, completion: (chatGroups: [ChatGroup]?, error: NSError?) -> Void) {
        CloudKitManager.sharedManager.fetchChatGroupsForUser(self, includeChatGroupDetails: includeDetails, completion: completion)
    }
    
    public func createChatGroupWithName(name: String, otherUsers: [User], completion: (group: ChatGroup?, error: NSError?) -> Void) {
        return CloudKitManager.sharedManager.createChatGroupCreatedBy(self, name: name, otherUsers: otherUsers, completion: completion)
    }
    
    /// Send a message to target group. The `constructedMessage` calls back immediately after it constructs a new message ready for uploading. On completion the `completion` block either has non-nil `message` or `error` depending on whether it is successfully done, respectively. The message will automatically append to target group after sending.
    public func sendMessageWithBody(body: String, toGroup recipientGroup: ChatGroup, constructedMessage: ((message: Message) -> Void)?, completion: (message: Message?, error: NSError?) -> Void) {
        CloudKitManager.sharedManager.sendMessageWithBody(body, toGroup: recipientGroup, fromSender: self, timeSent: NSDate(), constructedMessage: constructedMessage, completion: completion)
    }
    
    public func sendMessageWithBody(body: String, toGroup recipientGroup: ChatGroup, completion: (message: Message?, error: NSError?) -> Void) {
        sendMessageWithBody(body, toGroup: recipientGroup, constructedMessage: nil, completion: completion)
    }
    
    public func subscribeToChatGroupAndMessageChangesWithCompletion(completion: (error: NSError?) -> Void) {
        CloudKitManager.sharedManager.subscribeToChatGroupAndMessageChangesWithUser(self, completion: completion)
    }
}

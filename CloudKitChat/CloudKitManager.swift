//
//  CloudKitManager.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 7/23/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

// TEST USER: _01fedf281086291ad1fe466e6b28bdca
// TEST GROUP 1: 0337399F-34A9-48B9-88F5-82FF44444E37

import UIKit
import CloudKit

let CloudKitCustomTestContainer = "iCloud.edu.jhu.Test.CloudKitChat"

public typealias FetchUserCompletionBlock = (user: User?, error: NSError?) -> Void
public typealias FetchChatGroupsCompletionBlock = (chatGroups: [ChatGroup]?, error: NSError?) -> Void

public enum FetchModelOption {
    case FetchNonRelationalProperties
    case FetchFullProperties
}

var CurrentUser: User? {
    get {
        return CloudKitManager.sharedManager.currentUser
    }
}

// TODO: Cache using Realm
public class CloudKitManager: NSObject {
    var container: CKContainer
    var database: CKDatabase

    class var sharedManager: CloudKitManager {
        struct Singleton {
            static let instance = CloudKitManager()
        }
        return Singleton.instance
    }
    
    private(set) var currentUser: User?
    private(set) var lastServerChangeToken: CKServerChangeToken?
    
    override init() {
        container = CKContainer(identifier: CloudKitCustomTestContainer)
        database = container.publicCloudDatabase
    }
    
    func requestDiscoveryPermission(completion: (dicoverable: Bool, error: NSError?) -> Void) {
        self.container.requestApplicationPermission(.PermissionUserDiscoverability) {
            (applicationPermissionStatus: CKApplicationPermissionStatus, error: NSError!) in
            dispatch_async(dispatch_get_main_queue()) {
                completion(dicoverable: applicationPermissionStatus == .Granted, error: error)
            }
        }
    }
    
    /**
     * Discover users from contacts.
     * @param completion The completion handler
     * @discussion The user array it returns in the completion handler is not fetched, meaning there are only user IDs associated with them.
     */
    func discoverUsersFromContactWithCompletion(completion: (users: [User]?, error: NSError?) -> Void) {
        self.requestDiscoveryPermission {
            discoverable, error in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(users: nil, error: error)
                }
                return
            }
            self.container.discoverAllContactUserInfosWithCompletionHandler {
                discoverInfo, error in
                if error {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(users: nil, error: error)
                    }
                    return
                }
                let users: [User] = discoverInfo.filter {
                    perUserDiscoverInfo -> Bool in
                    return perUserDiscoverInfo.firstName != nil && perUserDiscoverInfo.lastName != nil
                }.map {
                    perUserDiscoverInfo -> User in
                    return User(recordID: perUserDiscoverInfo.userRecordID)
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(users: users, error: nil)
                }
            }
        }
    }
    
    func discoverUsersFromEmail(email: String, completion: (user: User?, error: NSError?) -> Void) {
        self.requestDiscoveryPermission {
            discoverable, error in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(user: nil, error: error)
                }
                return
            }
            self.container.discoverUserInfoWithEmailAddress(email) {
                discoverInfo, error in
                if error {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(user: nil, error: error)
                    }
                    return
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(user: User(recordID: discoverInfo.userRecordID), error: nil)
                }
            }
        }
    }
    
    /**
    * This fetches an `User` with full properties (`fetched() == true`).
    * @param completion The completion handler
    * @discussion This will fetch the current user and initialize an `User` instance with fetched properties. It will attempt to use discovery to get user's real name too. If that fails, it generates an `User_<ID>` string as the user name instead.
    */
    func fetchUserWithNameDiscovered(discoverName: Bool, completion: FetchUserCompletionBlock) {
        self.container.fetchUserRecordIDWithCompletionHandler {
            (userRecordID: CKRecordID!, error: NSError!) in
            if error {
                if error.code == CKErrorCode.NotAuthenticated.toRaw() {
                    // iCloud account not exist, or restricted
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(user: nil, error: error)
                }
                return
            }
            self.database.fetchRecordWithID(userRecordID) {
                userRecord, error in
                if error {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(user: nil, error: error)
                    }
                    return
                }
                var user = User(record: userRecord)
                self.currentUser = user
                if user.fetched() || !discoverName {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(user: user, error: nil)
                    }
                    return
                }
                self.container.discoverUserInfoWithUserRecordID(userRecordID) {
                    (userInfo: CKDiscoveredUserInfo!, error: NSError!) in
                    if !error {
                        if userInfo {
                            user.name = "\(userInfo.firstName) \(userInfo.lastName)"
                        } else {
                            user.name = "User_\(userInfo.userRecordID.recordName)"
                        }
                    } else {
                        user.name = "User_\(userInfo.userRecordID.recordName)"
                    }

                    userRecord.setObject(user.name, forKey: UserNameKey)
                    self.database.saveRecord(userRecord) {
                        savedRecord, error in
                        if error {
                            // TODO: error reporting if user name failed to save
                            println("User name not saved, error: \(error)")
                        }
                        self.currentUser = user
                        dispatch_async(dispatch_get_main_queue()) {
                            completion(user: user, error: nil)
                        }
                        return
                    }
                }
            }
        }
    }
    
    /**
    * Fetch a `CloudKitQueriable` instance's every property.
    * @param model The `CloudKitQueriable` model to fetch all properties in.
    * @param completion The completion handler. The fetched model is returned here.
    */
    func fetchedModelWithAllPropertiesFromModel(model: CloudKitQueriable, completion: (fetchedModel: CloudKitQueriable?, error: NSError?) -> Void) {
        self.database.fetchRecordWithID(model.recordID) {
            fetchedRecord, error in
            if error {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(fetchedModel: nil, error: error)
                }
                return
            }
            var fetchedModel: CloudKitQueriable
            switch fetchedRecord.recordType {
            case ChatGroupRecordType:
                fetchedModel = ChatGroup(record: fetchedRecord)
            case MessageRecordType:
                fetchedModel = Message(record: fetchedRecord)
            case UserRecordType:
                fetchedModel = User(record: fetchedRecord)
            default:
                dispatch_async(dispatch_get_main_queue()) {
                    completion(fetchedModel: nil, error: CloudKitChatError.UnknownRecordTypeError(fetchedRecord.recordType).error)
                }
                return
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(fetchedModel: fetchedModel, error: nil)
            }
        }
    }
    
    func fetchAllPropertiesInModel(model: CloudKitQueriable, fetchOption: FetchModelOption, completion: (error: NSError?) -> Void) {
        fetchedModelWithAllPropertiesFromModel(model) {
            fetchedModel, error in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(error: error)
                }
                return
            }
            if let user = fetchedModel as? User {
                let userModel = model as User
                userModel.name = user.name
                userModel.chatGroups = user.chatGroups
            } else if let message = fetchedModel as? Message {
                let messageModel = model as Message
                messageModel.sender = message.sender
                messageModel.recipientGroup = message.recipientGroup
                messageModel.body = message.body
                messageModel.timeSent = message.timeSent
            } else if let chatGroup = fetchedModel as? ChatGroup {
                let chatGroupModel = model as ChatGroup
                chatGroupModel.name = chatGroup.name
                chatGroupModel.messages = chatGroup.messages
                chatGroupModel.people = chatGroup.people
                chatGroupModel.owner = chatGroup.owner
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(error: CloudKitChatError.UnknownModelTypeError.error)
                }
                return
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(error: nil)
            }
        }
    }
    
    /**
    * Fetch a model collection.
    * @param list The model collection
    * @param completion The completion handler
    * @discussion This method will refetch the list of models regardless if they have already been fetched or not. It will NOT assign the fetched model collection to the source, so you may need to do it manually.
    */
    // BUG: Using generics causes Swift to crash
    func fetchModelCollection(list: [CloudKitQueriable], completion: (fetchedList: [CloudKitQueriable]?, error: NSError?) -> Void) {
        let recordIDs = list.map {
            model -> CKRecordID in
            return model.recordID
        }
        let fetchListOperation = CKFetchRecordsOperation(recordIDs: recordIDs)
        var fetchedList = [CloudKitQueriable]()
        var fetchError: NSError?
        fetchListOperation.perRecordCompletionBlock = {
            record, _, error in
            switch record.recordType {
            case UserRecordType:
                fetchedList.append(User(record: record))
            case MessageRecordType:
                fetchedList.append(Message(record: record))
            case ChatGroupRecordType:
                fetchedList.append(ChatGroup(record: record))
            default:
                fetchError = CloudKitChatError.UnknownRecordTypeError(record.recordType).error
            }
        }
        fetchListOperation.fetchRecordsCompletionBlock = {
            _, error in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(fetchedList: nil, error: error)
                }
                return
            } else if fetchError != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(fetchedList: nil, error: fetchError)
                }
                return
            }
            completion(fetchedList: fetchedList, error: nil)
        }
        self.database.addOperation(fetchListOperation)
    }
    
    // MARK: Chat Functionalities
    func createChatGroupCreatedBy(owner: User, name: String, otherUsers: [User], completion: (group: ChatGroup?, error: NSError?) -> Void) {
        let groupRecord = CKRecord(recordType: ChatGroupRecordType)
        groupRecord.setObject(name, forKey: ChatGroupNameKey)
        var userReferences = otherUsers.map {
            user -> CKReference in
            return CKReference(recordID: user.recordID, action: .None)
        }
        let ownerReference = CKReference(recordID: owner.recordID, action: .None)
        userReferences.append(CKReference(recordID: owner.recordID, action: .None))
        groupRecord.setObject(userReferences, forKey: ChatGroupPeopleKey)
        groupRecord.setObject(ownerReference, forKey: ChatGroupOwnerKey)
        groupRecord.setObject([], forKey: ChatGroupMessagesKey)
        
        let groupReference = CKReference(recordID: groupRecord.recordID, action: .None)
        var userIDs = otherUsers.map {
            user -> CKRecordID in
            return user.recordID
        }
        userIDs.append(owner.recordID)
        let fetchUsersOperation = CKFetchRecordsOperation(recordIDs: userIDs)
        var modifiedUserRecords = [CKRecord]()
        fetchUsersOperation.perRecordCompletionBlock = {
            userRecord, _, error in
            if error {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(group: nil, error: error)
                }
                return
            }
            var groupReferences: [CKReference]
            if let references = userRecord.objectForKey(UserChatGroupsKey) as? [CKReference] {
                groupReferences = references
            } else {
                groupReferences = []
            }
            groupReferences.append(groupReference)
            userRecord.setObject(groupReferences, forKey: UserChatGroupsKey)
            modifiedUserRecords.append(userRecord)
        }
        fetchUsersOperation.fetchRecordsCompletionBlock = {
            _, error in
            if error {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(group: nil, error: error)
                }
                return
            }
            let saveRecordsOperation = CKModifyRecordsOperation(recordsToSave: modifiedUserRecords, recordIDsToDelete: [])
            saveRecordsOperation.modifyRecordsCompletionBlock = {
                saved, deleted, error in
                if error {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(group: nil, error: error)
                    }
                    return
                }
                println("create chat saved: \(saved.count), deleted: \(deleted.count)")
                let group = ChatGroup(record: groupRecord)
                // Maybe it is not thread-safe?
                if owner.fetched() {
                    var newChatGroups = owner.chatGroups!
                    newChatGroups.append(group)
                    owner.chatGroups = newChatGroups
                }
                for otherUser in otherUsers {
                    if otherUser.fetched() {
                        var newChatGroups = owner.chatGroups!
                        newChatGroups.append(group)
                        owner.chatGroups = newChatGroups
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(group: group, error: nil)
                }
            }
            self.database.addOperation(saveRecordsOperation)
        }
        self.database.addOperation(fetchUsersOperation)
    }
    
    func fetchChatGroupsForUser(user: User, completion: FetchChatGroupsCompletionBlock) {
        fetchChatGroupsForUser(user, includeChatGroupDetails: false, completion: completion)
    }
    
    func fetchChatGroupsForUser(user: User, includeChatGroupDetails: Bool, completion: FetchChatGroupsCompletionBlock) {
        if !user.fetched() {
            dispatch_async(dispatch_get_main_queue()) {
                completion(chatGroups: nil, error: CloudKitChatError.ModelNotFetchedError(user).error)
            }
            return
        }
        fetchModelCollection(user.chatGroups!) {
            fetchedGroups, error in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(chatGroups: nil, error: error)
                }
                return
            }
            dispatch_async(dispatch_get_main_queue()) {
                user.chatGroups = (fetchedGroups as [ChatGroup])
                if !includeChatGroupDetails {
                    self.currentUser!.chatGroups = (fetchedGroups as [ChatGroup])
                    completion(chatGroups: (fetchedGroups as [ChatGroup]), error: nil)
                } else {
                    var fetchedError: NSError? = nil
                    let group = dispatch_group_create()
                    for fetchedGroup in (fetchedGroups as [ChatGroup]) {
                        dispatch_group_enter(group)
                        let subgroup = dispatch_group_create()
                        dispatch_group_enter(subgroup)
                        self.fetchModelCollection(fetchedGroup.messages!) {
                            fetchedMessages, error in
                            if error != nil {
                                fetchedError = error
                            }
                            fetchedGroup.messages = (fetchedMessages as [Message])
                            dispatch_group_leave(subgroup)
                        }
                        dispatch_group_enter(subgroup)
                        fetchedGroup.owner!.fetchWithCompletion {
                            error in
                            if error != nil {
                                fetchedError = error
                            }
                            dispatch_group_leave(subgroup)
                        }
                        dispatch_group_enter(subgroup)
                        self.fetchModelCollection(fetchedGroup.people!) {
                            fetchedPeople, error in
                            if error != nil {
                                fetchedError = error
                            }
                            fetchedGroup.people = (fetchedPeople as [User])
                            dispatch_group_leave(subgroup)
                        }
                        dispatch_group_notify(subgroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                            dispatch_group_leave(group)
                        }
                    }
                    dispatch_group_notify(group, dispatch_get_main_queue()) {
                        if fetchedError != nil {
                            completion(chatGroups: nil, error: fetchedError)
                        } else {
                            self.currentUser!.chatGroups = (fetchedGroups as [ChatGroup])
                            completion(chatGroups: (fetchedGroups as [ChatGroup]), error: nil)
                        }
                    }
                }
            }
        }
    }
    
    func sendMessageWithBody(body: String, toGroup recipientGroup: ChatGroup, fromSender sender: User, timeSent: NSDate,  completion: (message: Message?, error: NSError?) -> Void) {
        self.sendMessageWithBody(body, toGroup: recipientGroup, fromSender: sender, timeSent: timeSent, constructedMessage: nil, completion: completion)
    }
    
    func sendMessageWithBody(body: String, toGroup recipientGroup: ChatGroup, fromSender sender: User, timeSent: NSDate, constructedMessage: ((message: Message) -> Void)?, completion: (message: Message?, error: NSError?) -> Void) {
        let messageRecord = CKRecord(recordType: MessageRecordType)
        messageRecord.setObject(body, forKey: MessageBodyKey)
        messageRecord.setObject(CKReference(recordID: sender.recordID, action: .DeleteSelf), forKey: MessageSenderKey)
        messageRecord.setObject(CKReference(recordID: recipientGroup.recordID, action: .DeleteSelf), forKey: MessageRecipientGroupKey)
        messageRecord.setObject(timeSent, forKey: MessageTimeSentKey)
        var message = Message(record: messageRecord)
        if constructedMessage != nil {
            constructedMessage!(message: message)
        }
        
        let messageRecordReference = CKReference(recordID: messageRecord.recordID, action: .None)
        self.database.fetchRecordWithID(recipientGroup.recordID) {
            recipientGroupRecord, error in
            if error {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(message: nil, error: error)
                }
                return
            }
            let fetchedRecipientGroup = ChatGroup(record: recipientGroupRecord)
            if find(fetchedRecipientGroup.people!, sender) == nil {
                // User is not in the group he/she send message to
                // Abort mission! I repeat, abort mission!
                dispatch_async(dispatch_get_main_queue()) {
                    completion(message: nil, error: CloudKitChatError.WrongRecipentGroupError(sender, recipientGroup).error)
                }
                return
            }
            
            var chatGroupMessages = [CKReference]()
            if let references = recipientGroupRecord.objectForKey(ChatGroupMessagesKey) as? [CKReference] {
                chatGroupMessages = references
            }
            chatGroupMessages.append(messageRecordReference)
            recipientGroupRecord.setObject(chatGroupMessages, forKey: ChatGroupMessagesKey)
            
            let saveRecordsOperation = CKModifyRecordsOperation(recordsToSave: [recipientGroupRecord, messageRecord], recordIDsToDelete: [])
            saveRecordsOperation.modifyRecordsCompletionBlock = {
                _, _, error in
                if (error != nil) {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(message: nil, error: error)
                    }
                    return
                }
                message = Message(record: messageRecord)
                // Maybe it is not thread-safe?
                if recipientGroup.fetched() {
                    var newMessages = recipientGroup.messages!
                    newMessages.append(message)
                    recipientGroup.messages = newMessages
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(message: message, error: nil)
                }
            }
            self.database.addOperation(saveRecordsOperation)
        }
    }
    
    /**
    * Fetch all messages in a chat group. The messages retreived are sorted in ascending order (the latest is the last).
    * @param group The chat group to fetch messages from
    * @param completion The completion handler
    * @discussion This method will fetch chat group properties automatically if they have not already been fetched. The `messages` property in parameter `group` will also be updated upon completion.
    */
    // TODO: Limit need another -fetchedMessagesCount property
    func fetchMessagesInChatGroup(group: ChatGroup, messageLimit: Int?, completion: (messages: [Message]?, error: NSError?) -> Void) {
        if !group.fetched() {
            group.fetchWithCompletion {
                error in
                if error != nil {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(messages: nil, error: error)
                    }
                    return
                }
                self.fetchMessagesInChatGroup(group, messageLimit: messageLimit, completion: completion)
            }
        } else {
            var messagesToFetch: [Message] = group.messages!
            if messageLimit != nil {
                if messageLimit! < group.messages!.count {
                    messagesToFetch = Array(group.messages![group.messages!.count - messageLimit!..<group.messages!.count])
                }
            }
            let messageRecordIDs = group.messages!.map {
                message -> CKRecordID in
                return message.recordID
            }
            let fetchMessagesOperation = CKFetchRecordsOperation(recordIDs: messageRecordIDs)
            var fetchedMessages = [Message]()
            fetchMessagesOperation.perRecordCompletionBlock = {
                record, _, error in
                if (error != nil) {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(messages: nil, error: error)
                    }
                    return
                }
                fetchedMessages.append(Message(record: record))
            }
            fetchMessagesOperation.fetchRecordsCompletionBlock = {
                _, error in
                if (error != nil) {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(messages: nil, error: error)
                    }
                    return
                }
                
                group.messages = fetchedMessages.sorted {
                    firstMessage, secondMessage -> Bool in
                    return firstMessage < secondMessage
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(messages: group.messages, error: nil)
                }
            }
            self.database.addOperation(fetchMessagesOperation)
        }
    }
    
    internal func subscribeToChatGroupAndMessageChangesWithUser(user: User, completion: (error: NSError?) -> Void) {
        if !user.fetched() {
            dispatch_async(dispatch_get_main_queue()) {
                completion(error: CloudKitChatError.ModelNotFetchedError(user).error)
            }
            return
        }
        
        // Register for every chat group the user is involved for notification
        let messageSubscriptions = user.chatGroups!.map {
            chatGroup -> CKSubscription in
            let groupReference = CKReference(recordID: chatGroup.recordID, action: .DeleteSelf)
            let predicate = NSPredicate(format: "recipientGroup == %@", groupReference)
            let subscription = CKSubscription(recordType: MessageRecordType, predicate: predicate, options: .FiresOnRecordCreation)
            let notificationInfo = CKNotificationInfo()
            notificationInfo.shouldBadge = false
            notificationInfo.shouldSendContentAvailable = true
            if let groupName = chatGroup.name {
                notificationInfo.alertBody = "You have a new message from \(groupName)."
            } else {
                notificationInfo.alertBody = "You have a new message!"
            }
            subscription.notificationInfo = notificationInfo
            return subscription
        }
        
        // Register for user update notification. Because adding a chat group updates all related users' records, so all users invited will receive an update
        let userChangesSubscription = CKSubscription(recordType: UserRecordType, predicate: NSPredicate(value: true), options: .FiresOnRecordUpdate)
        let userNotificationInfo = CKNotificationInfo()
        userNotificationInfo.shouldBadge = false
        userNotificationInfo.shouldSendContentAvailable = true
        userChangesSubscription.notificationInfo = userNotificationInfo
        
        var allSubscriptions = messageSubscriptions
        allSubscriptions.append(userChangesSubscription)
        
        let addSubscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: allSubscriptions, subscriptionIDsToDelete: [])
        addSubscriptionOperation.modifySubscriptionsCompletionBlock = {
            saved, _, error in
            if error {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(error: error)
                }
                return
            }
            println("\(saved.count) subscriptions saved")
            dispatch_async(dispatch_get_main_queue()) {
                completion(error: nil)
            }
        }
        self.database.addOperation(addSubscriptionOperation)
    }
    
    func fetchNotificationChangesWithCompletion(completion: (notifications: [CKNotification]?, serverChangeToken: CKServerChangeToken?, error: NSError?) -> Void) {
        let fetchNotificationOps = CKFetchNotificationChangesOperation()
        var notifications = [CKNotification]()
        fetchNotificationOps.notificationChangedBlock = {
            notification in
            notifications.append(notification)
        }
        fetchNotificationOps.fetchNotificationChangesCompletionBlock = {
            serverChangeToken, error in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(notifications: nil, serverChangeToken: nil, error: error)
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(notifications: notifications, serverChangeToken: serverChangeToken, error: nil)
            }
        }
        self.container.addOperation(fetchNotificationOps)
    }
    
    // Only for testing
    func deleteAllSubscriptionsWithCompletion(completion: (error: NSError?) -> Void) {
        let fetchSubscriptionOps = CKFetchSubscriptionsOperation.fetchAllSubscriptionsOperation()
        fetchSubscriptionOps.fetchSubscriptionCompletionBlock = {
            subscriptionDict, error in
            if error {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(error: error)
                }
                return
            }
            var keys = [String]()
            for (key, value) in subscriptionDict {
                keys.append(key as String)
            }
            let deleteAllOps = CKModifySubscriptionsOperation(subscriptionsToSave: [], subscriptionIDsToDelete: keys)
            deleteAllOps.modifySubscriptionsCompletionBlock = {
                _, deleted, error in
                if error {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(error: error)
                    }
                    return
                }
                println("\(deleted.count) subscriptions deleted")
                dispatch_async(dispatch_get_main_queue()) {
                    completion(error: nil)
                }
            }
            self.database.addOperation(deleteAllOps)
        }
        self.database.addOperation(fetchSubscriptionOps)
    }
    
    func exitGroup(group: ChatGroup, user: User, completion: (error: NSError?) -> Void) {
        // TODO: exit group
    }
    
}

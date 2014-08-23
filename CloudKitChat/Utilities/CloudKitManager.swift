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
let CloudKitChatNewMessageReceivedNotification = "CloudKitChatNewMessageReceivedNotification"
let CloudKitChatNewMessagesKey = "CloudKitChatNewMessagesKey"

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
    private(set) var unfetchedMessages = [Message]()

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
                if error != nil {
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
                if error != nil {
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
    
    func setUserName(name: String, completion: (error: NSError?) -> Void) {
        self.container.fetchUserRecordIDWithCompletionHandler {
            (userRecordID: CKRecordID!, error: NSError!) in
            if error != nil {
                if error.code == CKErrorCode.NotAuthenticated.toRaw() {
                    // iCloud account not exist, or restricted
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(error: error)
                }
                return
            }
            self.database.fetchRecordWithID(userRecordID) {
                userRecord, error in
                if error != nil {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(error: error)
                    }
                    return
                }
                userRecord.setObject(name, forKey: UserNameKey)
                self.database.saveRecord(userRecord) {
                    savedRecord, error in
                    if error != nil {
                        dispatch_async(dispatch_get_main_queue()) {
                            completion(error: error)
                        }
                        return
                    }
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(error: nil)
                    }
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
            if error != nil {
                if error.code == CKErrorCode.NotAuthenticated.toRaw() {
                    // iCloud account not exist, or restricted
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(user: nil, error: error)
                }
                return
            }
            
            self.currentUser = User(recordID: userRecordID)
            self.fetchAllPropertiesInModel(self.currentUser!, fetchOption: .FetchNonRelationalProperties) {
                error in
                if error != nil && !error!.isFirstTimeRecordTypeNotCreated() {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(user: nil, error: error)
                    }
                    return
                }
                if self.currentUser!.fetched() || !discoverName {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(user: self.currentUser, error: nil)
                    }
                    return
                }
                
                self.container.discoverUserInfoWithUserRecordID(userRecordID) {
                    (userInfo: CKDiscoveredUserInfo!, error: NSError!) in
                    var name: String!
                    if error == nil {
                        if userInfo != nil {
                            name = "\(userInfo.firstName) \(userInfo.lastName)"
                        } else {
                            name = "User_\(userRecordID.recordName)"
                        }
                    } else {
                        name = "User_\(userInfo.userRecordID.recordName)"
                    }
                    
                    self.database.fetchRecordWithID(self.currentUser!.recordID) {
                        userRecord, error in
                        userRecord.setObject(name, forKey: UserNameKey)
                        self.database.saveRecord(userRecord) {
                            savedRecord, error in
                            if error != nil {
                                // TODO: error reporting if user name failed to save
                                println("User name not saved, error: \(error)")
                            } else {
                                self.currentUser! = User(record: userRecord)
                            }
                            dispatch_async(dispatch_get_main_queue()) {
                                completion(user: self.currentUser, error: nil)
                            }
                            return
                        }
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
            if error != nil {
                if model is User && error.code == CKErrorCode.UnknownItem.toRaw() {
                    // First time uninitialized user
//                    let newUserRecord = CKRecord(recordType: UserRecordType, recordID: model.recordID)
//                    newUserRecord.setObject("User_\(model.recordID)", forKey: "name")
//                    self.database.saveRecord(newUserRecord) {
//                        record, error in
//                        if error != nil {
//                            dispatch_async(dispatch_get_main_queue()) {
//                                completion(fetchedModel: nil, error: error)
//                            }
//                            return
//                        }
//                        self.fetchedModelWithAllPropertiesFromModel(model, completion: completion)
//                    }
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(fetchedModel: nil, error: error)
                    }
                }
                return
            }
            
            let recordFetchCompletion: (queryError: NSError?) -> Void = {
                queryError in
                var fetchedModel: CloudKitQueriable?
                var fetchError: NSError?
                switch fetchedRecord.recordType {
                case UserRecordType:
                    fetchedModel = User(record: fetchedRecord)
                case MessageRecordType:
                    fetchedModel = Message(record: fetchedRecord)
                case ChatGroupRecordType:
                    fetchedModel = ChatGroup(record: fetchedRecord)
                default:
                    fetchError = CloudKitChatError.UnknownRecordTypeError(fetchedRecord.recordType).error
                }
                dispatch_async(dispatch_get_main_queue()) {
                    completion(fetchedModel: fetchedModel, error: queryError ?? fetchError)
                }
            }
            
            var queryError: NSError?
            if fetchedRecord.recordType == UserRecordType {
                let userReference = CKReference(recordID: self.currentUser!.recordID, action: .None)
                let queryPeopleOp = CKQueryOperation(query: CKQuery(recordType: ChatGroupRecordType, predicate: NSPredicate(format: "%K CONTAINS %@", ChatGroupPeopleKey, userReference)))
                queryPeopleOp.desiredKeys = []
                var people = [CKReference]()
                queryPeopleOp.recordFetchedBlock = {
                    record in
                    people.append(CKReference(recordID: record.recordID, action: .None))
                }
                queryPeopleOp.queryCompletionBlock = {
                    _, error in
                    if error != nil {
                        queryError = error
                    }
                    fetchedRecord.setObject(people, forKey: UserChatGroupsKey)
                    recordFetchCompletion(queryError: queryError)
                }
                self.database.addOperation(queryPeopleOp)
            } else if fetchedRecord.recordType == ChatGroupRecordType {
                let messageGroupReference = CKReference(recordID: fetchedRecord.recordID, action: .DeleteSelf)
                let queryMessagesOp = CKQueryOperation(query: CKQuery(recordType: MessageRecordType, predicate: NSPredicate(format: "%K == %@", MessageRecipientGroupKey, messageGroupReference)))
                queryMessagesOp.desiredKeys = []
                var messages = [CKReference]()
                queryMessagesOp.recordFetchedBlock = {
                    record in
                    messages.append(CKReference(recordID: record.recordID, action: .None))
                }
                queryMessagesOp.queryCompletionBlock = {
                    _, error in
                    if error != nil {
                        queryError = error
                    }
                    fetchedRecord.setObject(messages, forKey: ChatGroupMessagesKey)
                    recordFetchCompletion(queryError: queryError)
                }
                self.database.addOperation(queryMessagesOp)
            } else {
                recordFetchCompletion(queryError: nil)
            }
        }
    }
    
    func fetchAllPropertiesInModel(model: CloudKitQueriable, fetchOption: FetchModelOption, completion: (error: NSError?) -> Void) {
        fetchedModelWithAllPropertiesFromModel(model) {
            fetchedModel, error in
            if error != nil && !error!.isFirstTimeRecordTypeNotCreated() {
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
                completion(error: error)
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
        var tempChatGroupRecords = [CKRecord]()
        var tempUserRecords = [CKRecord]()
        var fetchError: NSError?
        fetchListOperation.perRecordCompletionBlock = {
            record, _, error in
            if record != nil {
                switch record.recordType {
                case UserRecordType:
                    tempUserRecords.append(record)
                case MessageRecordType:
                    fetchedList.append(Message(record: record))
                case ChatGroupRecordType:
                    tempChatGroupRecords.append(record)
                default:
                    fetchError = CloudKitChatError.UnknownRecordTypeError(record.recordType).error
                }
            }
        }
        fetchListOperation.fetchRecordsCompletionBlock = {
            _, error in
            if error != nil && error.code != CKErrorCode.PartialFailure.toRaw() {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(fetchedList: nil, error: error)
                }
                return
            }
            
            let completion: (queryError: NSError?) -> Void = {
                error in
                dispatch_async(dispatch_get_main_queue()) {
                    if fetchedList.isEmpty && fetchError != nil {
                        completion(fetchedList: nil, error: fetchError ?? error)
                    } else {
                        completion(fetchedList: fetchedList, error: error)
                    }
                }
            }
            
            var queryError: NSError?
            if !tempChatGroupRecords.isEmpty {
                var messageDict = [NSPredicate: [CKReference]]()
                var messageQueryRecordDict = [NSPredicate: CKRecord]()
                let syncGroup = dispatch_group_create()
                for chatGroupRecord in tempChatGroupRecords {
                    dispatch_group_enter(syncGroup)
                    let messageGroupReference = CKReference(recordID: chatGroupRecord.recordID, action: .DeleteSelf)
                    let messageQuery = CKQuery(recordType: MessageRecordType, predicate: NSPredicate(format: "%K == %@", MessageRecipientGroupKey, messageGroupReference))
                    let queryMessagesOp = CKQueryOperation(query: messageQuery)
                    var fetchResult = [CKReference]()
                    messageDict[messageQuery.predicate] = fetchResult
                    messageQueryRecordDict[messageQuery.predicate] = chatGroupRecord
                    queryMessagesOp.desiredKeys = []
                    queryMessagesOp.recordFetchedBlock = {
                        record in
                        messageDict[queryMessagesOp.query.predicate]!.append(CKReference(recordID: record.recordID, action: .None))
                    }
                    queryMessagesOp.queryCompletionBlock = {
                        _, error in
                        if error != nil {
                            queryError = error
                        }
                        messageQueryRecordDict[queryMessagesOp.query.predicate]!.setObject(messageDict[queryMessagesOp.query.predicate]!, forKey: ChatGroupMessagesKey)
                        dispatch_group_leave(syncGroup)
                    }
                    self.database.addOperation(queryMessagesOp)
                }
                dispatch_group_notify(syncGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
                    fetchedList = tempChatGroupRecords.map {
                        chatGroupRecord -> ChatGroup in
                        return ChatGroup(record: chatGroupRecord)
                    }
                    completion(queryError: queryError)
                }
            } else if !tempUserRecords.isEmpty {
                var userDict = [NSPredicate: [CKReference]]()
                var userQueryRecordDict = [NSPredicate: CKRecord]()
                let syncGroup = dispatch_group_create()
                for userRecord in tempUserRecords {
                    dispatch_group_enter(syncGroup)
                    let userReference = CKReference(recordID: userRecord.recordID, action: .None)
                    let userQuery = CKQuery(recordType: ChatGroupRecordType, predicate: NSPredicate(format: "%K CONTAINS %@", ChatGroupPeopleKey, userReference))
                    let queryPeopleOp = CKQueryOperation(query: userQuery)
                    var fetchResult = [CKReference]()
                    userDict[userQuery.predicate] = fetchResult
                    userQueryRecordDict[userQuery.predicate] = userRecord
                    queryPeopleOp.desiredKeys = []
                    queryPeopleOp.recordFetchedBlock = {
                        record in
                        userDict[queryPeopleOp.query.predicate]!.append(CKReference(recordID: record.recordID, action: .None))
                    }
                    queryPeopleOp.queryCompletionBlock = {
                        _, error in
                        if error != nil {
                            queryError = error
                        }
                    userQueryRecordDict[queryPeopleOp.query.predicate]!.setObject(userDict[queryPeopleOp.query.predicate]!, forKey: UserChatGroupsKey)
                        dispatch_group_leave(syncGroup)
                    }
                    self.database.addOperation(queryPeopleOp)
                }
                dispatch_group_notify(syncGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
                    fetchedList = tempUserRecords.map {
                        chatGroupRecord -> User in
                        return User(record: chatGroupRecord)
                    }
                    completion(queryError: queryError)
                }
            } else {
                completion(queryError: nil)
            }
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
            if error != nil {
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
            if (error != nil) {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(group: nil, error: error)
                }
                return
            }
            let saveRecordsOperation = CKModifyRecordsOperation(recordsToSave: modifiedUserRecords, recordIDsToDelete: [])
            saveRecordsOperation.modifyRecordsCompletionBlock = {
                saved, deleted, error in
                if error != nil {
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
        
        if !sender.fetched() {
            completion(message: nil, error: CloudKitChatError.ModelNotFetchedError(sender).error)
            return
        }
        
        if find(sender.chatGroups!, recipientGroup) == nil {
            dispatch_async(dispatch_get_main_queue()) {
                completion(message: nil, error: CloudKitChatError.WrongRecipentGroupError(sender, recipientGroup).error)
            }
            return
        }
        
        let saveRecordsOperation = CKModifyRecordsOperation(recordsToSave: [messageRecord], recordIDsToDelete: [])
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
//        let userChangesSubscription = CKSubscription(recordType: UserRecordType, predicate: NSPredicate(value: true), options: .FiresOnRecordUpdate)
//        let userNotificationInfo = CKNotificationInfo()
//        userNotificationInfo.shouldSendContentAvailable = true
//        userChangesSubscription.notificationInfo = userNotificationInfo
//        
        var allSubscriptions = messageSubscriptions
//        allSubscriptions.append(userChangesSubscription)
        
        let addSubscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: allSubscriptions, subscriptionIDsToDelete: [])
        addSubscriptionOperation.modifySubscriptionsCompletionBlock = {
            saved, _, error in
            if error != nil {
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
    
    func fetchNotificationChangesWithCompletion(completion: (messageRecordIDs: [CKRecordID]?, error: NSError?) -> Void) {
        let fetchNotificationOps = CKFetchNotificationChangesOperation(previousServerChangeToken: lastServerChangeToken)
        var notifications = [CKNotification]()
        fetchNotificationOps.notificationChangedBlock = {
            notification in
            notifications.append(notification)
        }
        fetchNotificationOps.fetchNotificationChangesCompletionBlock = {
            serverChangeToken, error in
            if error != nil {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(messageRecordIDs: nil, error: error)
                }
                return
            }
            self.lastServerChangeToken = serverChangeToken
        
//            let markNotificationOps = CKMarkNotificationsReadOperation(notificationIDsToMarkRead: notifications.map {
//                notification -> CKNotificationID in
//                return notification.notificationID
//                })
//            markNotificationOps.markNotificationsReadCompletionBlock = {
//                notificationIDsMarked, error in
//                if error != nil && error.code != CKErrorCode.PartialFailure.toRaw() {
//                    dispatch_async(dispatch_get_main_queue()) {
//                        completion(messageRecordIDs: nil, error: error)
//                    }
//                    return
//                }
//                println("\(notificationIDsMarked.count) notifications marked read.")
//                notifications = notifications.filter {
//                    notification -> Bool in
//                    return notification.notificationType == .ReadNotification
//                }
                for notification in notifications {
                    let messageRecordID = (notification as CKQueryNotification).recordID
                    var exists = false
                    for existingUnfetchedMessage in self.unfetchedMessages {
                        if existingUnfetchedMessage.recordID.recordName == messageRecordID.recordName {
                            exists = true
                            break
                        }
                    }
                    if !exists {
                        synchronized(self) {
                            self.unfetchedMessages.append(Message(recordID: messageRecordID))
                        }
                    }
                }
                self.fetchChangesWithCompletion {
                    fetchedMessages, updatedUsers, error in
                    if error != nil && error!.code != CKErrorCode.PartialFailure.toRaw() {
                        dispatch_async(dispatch_get_main_queue()) {
                            completion(messageRecordIDs: nil, error: error)
                        }
                        return
                    }
                    NSNotificationCenter.defaultCenter().postNotificationName(CloudKitChatNewMessageReceivedNotification, object: self, userInfo: [CloudKitChatNewMessagesKey: (fetchedMessages! as [Message])])
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(messageRecordIDs: notifications.map {
                            notification -> CKRecordID in
                            return (notification as CKQueryNotification).recordID
                            }, error: nil)
                    }
                }
//            }
//            self.container.addOperation(markNotificationOps)
        }
        self.container.addOperation(fetchNotificationOps)
    }
    
    private func fetchChangesWithCompletion(completion: (fetchedNewMessages: [Message]?, updatedUsers: [User]?, error: NSError?) -> Void) {
        fetchModelCollection(unfetchedMessages) {
            changedModels, error in
            if error != nil && error!.code != CKErrorCode.PartialFailure.toRaw() {
                dispatch_async(dispatch_get_main_queue()) {
                    completion(fetchedNewMessages: nil, updatedUsers: nil, error: error)
                }
                return
            }
            let newMessages = changedModels!.filter {
                model -> Bool in
                return model is Message
            }
            let updatedUsers = changedModels!.filter {
                model -> Bool in
                return model is User
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(fetchedNewMessages: (newMessages as [Message]), updatedUsers: (updatedUsers as [User]), error: error)
            }
        }
    }
    
    func markNewMessagesProcessed(newMessagesProcessed: [Message]) {
        for message in newMessagesProcessed {
            if let index = find(unfetchedMessages, message) {
                unfetchedMessages.removeAtIndex(index)
            }
        }
    }
    
    // Only for testing
    func deleteAllSubscriptionsWithCompletion(completion: (error: NSError?) -> Void) {
        let fetchSubscriptionOps = CKFetchSubscriptionsOperation.fetchAllSubscriptionsOperation()
        fetchSubscriptionOps.fetchSubscriptionCompletionBlock = {
            subscriptionDict, error in
            if error != nil {
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
                if error != nil {
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
    
    // Only for testing
    func markAllNotificationsReadWithCompletion(completion: (error: NSError?) -> Void) {
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
                    completion(error: error)
                }
                return
            }
            let markNotificationOps = CKMarkNotificationsReadOperation(notificationIDsToMarkRead: notifications.map {
                notification -> CKNotificationID in
                return notification.notificationID
            })
            markNotificationOps.markNotificationsReadCompletionBlock = {
                notificationIDsMarked, error in
                if error != nil && error.code != CKErrorCode.PartialFailure.toRaw() {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(error: error)
                    }
                    return
                }
                println("#\(notificationIDsMarked?.count ?? 0) notifications marked read.")
                dispatch_async(dispatch_get_main_queue()) {
                    completion(error: error)
                }
            }
            self.container.addOperation(markNotificationOps)
        }
        self.container.addOperation(fetchNotificationOps)

    }
    
    // Only for testing
    func queryOneToManyRelation(completion: (error: NSError?) -> Void) {
        let reference = CKReference(recordID: currentUser!.recordID, action: .None)
        let query = CKQuery(recordType: ChatGroupRecordType, predicate: NSPredicate(format: "people CONTAINS %@", reference))
        let queryOp = CKQueryOperation(query: query)
        var records = [CKRecord]()
        queryOp.queryCompletionBlock = {
            cursor, error in
            println("Records: \(records), error: \(error)")
            dispatch_async(dispatch_get_main_queue()) {
                completion(error: error)
            }
        }
        queryOp.recordFetchedBlock = {
            record in
            records.append(record)
        }
        self.database.addOperation(queryOp)
    }
    
    func exitGroup(group: ChatGroup, user: User, completion: (error: NSError?) -> Void) {
        // TODO: exit group
    }
    
}

func synchronized(lock: AnyObject, closure: () -> Void) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}
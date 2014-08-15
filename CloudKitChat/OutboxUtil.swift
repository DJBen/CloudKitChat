//
//  OutboxUtil.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 8/7/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit

var Outboxes: OutboxUtil {
    get {
        return OutboxUtil.sharedOutboxes
    }
}

class OutboxUtil {
    class var sharedOutboxes: OutboxUtil {
        struct Singleton {
            static let instance = OutboxUtil()
        }
        return Singleton.instance
    }
    
    var outboxes = [ChatGroup: Outbox]()
    
    subscript(chatGroup: ChatGroup) -> Outbox {
        get {
            if let outbox = outboxes[chatGroup] {
                return outbox
            } else {
                outboxes[chatGroup] = Outbox(chatGroup: chatGroup)
                return outboxes[chatGroup]!
            }
        }
    }
}

class Outbox: DebugPrintable {
    var draft = String()
    var pendingMessages = [Message]()
    let chatGroup: ChatGroup
    
    init(chatGroup: ChatGroup) {
        self.chatGroup = chatGroup
    }
    
    var debugDescription: String {
        get {
            return "Outbox_\(chatGroup.recordID.recordName) = {drafts: \(draft), pendingMessages: \(pendingMessages)}"
        }
    }
    
    // TODO: Maybe we need to stop the uploading of message when found duplicate?
    func addMessage(message: Message) {
        if let index = find(pendingMessages, message) {
            pendingMessages.removeAtIndex(index)
        }
        pendingMessages.append(message)
    }
    
    func deleteMessage(message: Message) -> Bool {
        if let index = find(pendingMessages, message) {
            pendingMessages.removeAtIndex(index)
            return true
        } else {
            return false
        }
    }
    
    func deleteAllMessages() {
        pendingMessages.removeAll(keepCapacity: false)
    }
}

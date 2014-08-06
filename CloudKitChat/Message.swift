//
//  Message.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 7/23/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit
import CloudKit

let MessageRecordType: String = "Message"
let MessageSenderKey = "sender"
let MessageRecipientGroupKey = "recipientGroup"
let MessageBodyKey = "body"
let MessageTimeSentKey = "timeSent"

// TODO: Realm
public class Message: CloudKitQueriable, Comparable {
    public var sender: User?
    public var recipientGroup: ChatGroup?
    public var body: String?
    public var timeSent: NSDate?
    public var timeSentString: NSString? {
        get {
            if timeSent != nil {
                return nil
            }
            return formatDate(timeSent!)
        }
    }
    
    public override var debugDescription: String {
        get {
            return "Message = {recordID: \(recordID.recordName), fetched: \(fetched()), body: \(body), timeSent: \(timeSent), sender: \(sender?.recordID.recordName), recipient: \(recipientGroup?.recordID.recordName)}"
        }
    }
    
    public var incoming: Bool {
        get {
            if !self.fetched() || CloudKitManager.sharedManager.currentUser != nil {
                return true
            }
            return self.sender! == CloudKitManager.sharedManager.currentUser
        }
    }
    
    public override init(recordID: CKRecordID) {
        super.init(recordID: recordID)
    }
    
    public convenience init(recordID: CKRecordID, sender: User?, recipientGroup: ChatGroup?, body: String?, sentTime: NSDate) {
        self.init(recordID: recordID)
        self.sender = sender
        self.recipientGroup = recipientGroup
        self.body = body
        self.timeSent = sentTime
    }
    
    public convenience override init(record: CKRecord) {
        if record.recordType != MessageRecordType {
            fatalError("Type mismatch: CKRecord's recordType must fit class' type")
        }
        self.init(recordID: record.recordID)
        if let sender = record.objectForKey(MessageSenderKey) as? CKReference {
            self.sender = User(recordID: sender.recordID)
        }
        if let body = record.objectForKey(MessageBodyKey) as? String {
            self.body = body
        }
        if let recipientGroup = record.objectForKey(MessageRecipientGroupKey) as? CKReference {
            self.recipientGroup = ChatGroup(recordID: recipientGroup.recordID)
        }
        if let sentTime = record.objectForKey(MessageTimeSentKey) as? NSDate {
            self.timeSent = sentTime
        }
    }
    
    override public func fetched() -> Bool  {
        return self.sender != nil && self.recipientGroup != nil && self.body != nil && self.timeSent != nil
    }
    
    private func formatDate(date: NSDate) -> String {
        let calendar = NSCalendar.currentCalendar()
        var dateFormatter = NSDateFormatter()

        let last18hours = (-18*60*60 < date.timeIntervalSinceNow)
        let isToday = calendar.isDateInToday(date)
        let isLast7Days = (calendar.compareDate(NSDate(timeIntervalSinceNow: -7*24*60*60), toDate: date, toUnitGranularity: .CalendarUnitDay) == NSComparisonResult.OrderedAscending)
        
        if last18hours || isToday {
            dateFormatter.dateStyle = .NoStyle
            dateFormatter.timeStyle = .ShortStyle
        } else if isLast7Days {
            dateFormatter.dateFormat = "ccc"
        } else {
            dateFormatter.dateStyle = .ShortStyle
            dateFormatter.timeStyle = .NoStyle
        }
        return dateFormatter.stringFromDate(date)
    }
}

public func < (lhs: Message , rhs: Message) -> Bool {
    if !lhs.fetched() || !rhs.fetched() {
        return false
    }
    return lhs.timeSent!.compare(rhs.timeSent!) == NSComparisonResult.OrderedAscending
}
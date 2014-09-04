//
//  ErrorUtil.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 8/5/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit
import CloudKit

let CloudKitChatErrorDomain = "CloudKitChatErrorDomain"

public enum CloudKitChatError {
    case UnknownRecordTypeError(String)
    case UnknownModelTypeError
    case ModelNotFetchedError(CloudKitQueriable)
    case WrongRecipentGroupError(User, ChatGroup)
    
    public var errorCode: Int {
        get {
            switch self {
            case .UnknownRecordTypeError(let _):
                return 2
            case .UnknownModelTypeError:
                return 3
            case .ModelNotFetchedError(let _):
                return 4
            case .WrongRecipentGroupError(let _, let _):
                return 5
            }
        }
    }
    
    public var error: NSError {
        get {
            switch self {
            case .UnknownRecordTypeError(let recordType):
                return NSError(domain: CloudKitChatErrorDomain, code: self.errorCode, userInfo: [NSLocalizedDescriptionKey: "Unknown type of record \(recordType)"])
            case .UnknownModelTypeError:
                return NSError(domain: CloudKitChatErrorDomain, code: self.errorCode, userInfo: [NSLocalizedDescriptionKey: "Unknown type of model"])
            case .ModelNotFetchedError(let model):
                return NSError(domain: CloudKitChatErrorDomain, code: self.errorCode, userInfo: [NSLocalizedDescriptionKey: "Model \(model.recordID) not fetched"])
            case .WrongRecipentGroupError(let user, let chatGroup):
                return NSError(domain: CloudKitChatErrorDomain, code: self.errorCode, userInfo: [NSLocalizedDescriptionKey: "User \(user.recordID) attempts to send message to recipient group \(chatGroup.recordID) to which he/she doesn't belong"])
            }
        }
    }
}

public extension NSError {
    func isPartialError() -> Bool {
        return self.code == CKErrorCode.PartialFailure.toRaw()
    }

    func isDuplicateSubscription() -> Bool {
        if self.code == CKErrorCode.PartialFailure.toRaw() {
            let partialErrors = (self.userInfo![CKPartialErrorsByItemIDKey]! as [String: NSError]).values.array
            for partialError in partialErrors {
                if partialError.code != CKErrorCode.ServerRejectedRequest.toRaw() {
                    return false
                }
            }
        }
        return true
    }
    
    func isFirstTimeRecordTypeNotCreated() -> Bool {
        if self.code == CKErrorCode.UnknownItem.toRaw() {
            return true
        }
        return false
    }
}

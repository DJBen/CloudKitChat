//
//  ErrorUtil.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 8/5/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit

let CloudKitChatErrorDomain = "CloudKitChatErrorDomain"

public enum CloudKitChatError {
    case UnknownRecordTypeError(String)
    case UnknownModelTypeError
    case ModelNotFetchedError(CloudKitQueriable)
    case WrongRecipentGroupError(User, ChatGroup)
    
    public func errorCode() -> Int {
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
    
    public func error() -> NSError {
        switch self {
        case .UnknownRecordTypeError(let recordType):
            return NSError(domain: CloudKitChatErrorDomain, code: self.errorCode(), userInfo: [NSLocalizedDescriptionKey: "Unknown type of record \(recordType)"])
        case .UnknownModelTypeError:
            return NSError(domain: CloudKitChatErrorDomain, code: self.errorCode(), userInfo: [NSLocalizedDescriptionKey: "Unknown type of model"])
        case .ModelNotFetchedError(let model):
            return NSError(domain: CloudKitChatErrorDomain, code: self.errorCode(), userInfo: [NSLocalizedDescriptionKey: "Model \(model.recordID) not fetched"])
        case .WrongRecipentGroupError(let user, let chatGroup):
            return NSError(domain: CloudKitChatErrorDomain, code: self.errorCode(), userInfo: [NSLocalizedDescriptionKey: "User \(user.recordID) attempts to send message to recipient group \(chatGroup.recordID) to which he/she doesn't belong"])
        }
    }
}

//
//  AudioUtil.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 8/24/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import AudioToolbox

class AudioUtil: NSObject {
    class func playMessageOutgoingSound() {
        var soundID: SystemSoundID = 0
        let soundURL = CFBundleCopyResourceURL(CFBundleGetMainBundle(), "MessageOutgoing", "aiff", nil)
        AudioServicesCreateSystemSoundID(soundURL, &soundID)
        AudioServicesPlaySystemSound(soundID)
    }
    
    class func playMessageIncomingSound() {
        var soundID: SystemSoundID = 0
        let soundURL = CFBundleCopyResourceURL(CFBundleGetMainBundle(), "MessageIncoming", "aiff", nil)
        AudioServicesCreateSystemSoundID(soundURL, &soundID)
        AudioServicesPlaySystemSound(soundID)
    }
    
    class func vibrate() {
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
}

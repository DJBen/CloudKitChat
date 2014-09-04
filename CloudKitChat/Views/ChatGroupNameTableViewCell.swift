//
//  ChatGroupNameTableViewCell.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 8/24/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit

let ChatGroupNameTableViewCellIdentifier = "chatGroupNameCell"

class ChatGroupNameTableViewCell: UITableViewCell {

    @IBOutlet weak var chatGroupNameTextField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

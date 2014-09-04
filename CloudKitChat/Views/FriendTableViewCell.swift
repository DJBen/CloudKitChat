//
//  FriendTableViewCell.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 8/23/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit

let FriendTableViewCellIdentifier = "friendCell"

class FriendTableViewCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var selectedImageView: UIImageView!
    var chosen: Bool = false {
        didSet {
            selectedImageView.image = UIImage(named: self.chosen ? "Selected" : "Unselected")
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func toggle() {
        self.chosen = !self.chosen
    }
}

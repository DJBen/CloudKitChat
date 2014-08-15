import UIKit

let chatCellHeight: CGFloat = 72
let chatCellInsetLeft = chatCellHeight + 8

class ChatCell: UITableViewCell {
    let userPictureImageView: UIImageView
    let userNameLabel: UILabel
    let lastMessageTextLabel: UILabel
    let lastMessageSentDateLabel: UILabel
    let userNameInitialsLabel: UILabel
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String) {
        userPictureImageView = UIImageView(frame: CGRectZero)
        userNameLabel = UILabel(frame: CGRectZero)
        lastMessageTextLabel = UILabel(frame: CGRectZero)
        lastMessageSentDateLabel = UILabel(frame: CGRectZero)
        userNameInitialsLabel = UILabel(frame: CGRectZero)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init(coder aDecoder: NSCoder!) {
        userPictureImageView = UIImageView(frame: CGRectZero)
        userNameLabel = UILabel(frame: CGRectZero)
        lastMessageTextLabel = UILabel(frame: CGRectZero)
        lastMessageSentDateLabel = UILabel(frame: CGRectZero)
        userNameInitialsLabel = UILabel(frame: CGRectZero)
        super.init(coder: aDecoder)
        setupViews()
    }

    func configureWithChatGroup(chatGroup: ChatGroup) {
        if !chatGroup.fetched() {
            return
        }
        userPictureImageView.image = chatGroup.people![0].profilePicture
        
        if !userPictureImageView.image {
            if chatGroup.people![0].name!.initials.lengthOfBytesUsingEncoding(NSASCIIStringEncoding) == 0 {
                userPictureImageView.image = UIImage(named: "ProfilePicture")
                userNameInitialsLabel.hidden = true
            } else {
                userNameInitialsLabel.text = chatGroup.people![0].name!.initials
                userNameInitialsLabel.hidden = false
            }
        } else {
            userNameInitialsLabel.hidden = true
        }

        userNameLabel.text = chatGroup.owner!.name!
        lastMessageTextLabel.text = chatGroup.lastMessage?.body ?? ""
        lastMessageSentDateLabel.text = chatGroup.lastMessage?.timeSentString ?? "Unknown Time"
    }
    
    private func setupViews() {
        let pictureSize: CGFloat = 64
        userPictureImageView.frame = CGRect(x: 8, y: (chatCellHeight-pictureSize)/2, width: pictureSize, height: pictureSize)
        userPictureImageView.backgroundColor = UIColor(white: 238/255, alpha: 1)
        userPictureImageView.layer.cornerRadius = pictureSize/2
        userPictureImageView.layer.masksToBounds = true
        
        userNameLabel.backgroundColor = UIColor.whiteColor()
        userNameLabel.font = UIFont.systemFontOfSize(17)
        
        lastMessageSentDateLabel.autoresizingMask = .FlexibleLeftMargin
        lastMessageSentDateLabel.backgroundColor = UIColor.whiteColor()
        lastMessageSentDateLabel.font = UIFont.systemFontOfSize(15)
        lastMessageSentDateLabel.textColor = lastMessageTextLabel.textColor
        
        lastMessageTextLabel.backgroundColor = UIColor.whiteColor()
        lastMessageTextLabel.font = UIFont.systemFontOfSize(15)
        lastMessageTextLabel.numberOfLines = 2
        lastMessageTextLabel.textColor = UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1)
        
        userNameInitialsLabel.textColor = UIColor(white: 128/255, alpha: 1)
        userNameInitialsLabel.font = UIFont.systemFontOfSize(22)
        userNameInitialsLabel.textAlignment = .Center
        userNameInitialsLabel.hidden = true
        
        contentView.addSubview(userPictureImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(lastMessageTextLabel)
        contentView.addSubview(lastMessageSentDateLabel)
        userPictureImageView.addSubview(userNameInitialsLabel)
        
        userNameLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        contentView.addConstraint(NSLayoutConstraint(item: userNameLabel, attribute: .Left, relatedBy: .Equal, toItem: contentView, attribute: .Left, multiplier: 1, constant: chatCellInsetLeft))
        contentView.addConstraint(NSLayoutConstraint(item: userNameLabel, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1, constant: 6))
        
        lastMessageTextLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        contentView.addConstraint(NSLayoutConstraint(item: lastMessageTextLabel, attribute: .Left, relatedBy: .Equal, toItem: userNameLabel, attribute: .Left, multiplier: 1, constant: 0))
        contentView.addConstraint(NSLayoutConstraint(item: lastMessageTextLabel, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1, constant: 28))
        contentView.addConstraint(NSLayoutConstraint(item: lastMessageTextLabel, attribute: .Right, relatedBy: .Equal, toItem: contentView, attribute: .Right, multiplier: 1, constant: -7))
        contentView.addConstraint(NSLayoutConstraint(item: lastMessageTextLabel, attribute: .Bottom, relatedBy: .LessThanOrEqual, toItem: contentView, attribute: .Bottom, multiplier: 1, constant: -4))
        
        lastMessageSentDateLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        contentView.addConstraint(NSLayoutConstraint(item: lastMessageSentDateLabel, attribute: .Left, relatedBy: .Equal, toItem: userNameLabel, attribute: .Right, multiplier: 1, constant: 2))
        contentView.addConstraint(NSLayoutConstraint(item: lastMessageSentDateLabel, attribute: .Right, relatedBy: .Equal, toItem: contentView, attribute: .Right, multiplier: 1, constant: -7))
        contentView.addConstraint(NSLayoutConstraint(item: lastMessageSentDateLabel, attribute: .Baseline, relatedBy: .Equal, toItem: userNameLabel, attribute: .Baseline, multiplier: 1, constant: 0))
        
        userNameInitialsLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        userPictureImageView.addConstraint(NSLayoutConstraint(item: userNameInitialsLabel, attribute: .Left, relatedBy: .Equal, toItem: userPictureImageView, attribute: .Left, multiplier: 1, constant: 0))
        userPictureImageView.addConstraint(NSLayoutConstraint(item: userNameInitialsLabel, attribute: .Right, relatedBy: .Equal, toItem: userPictureImageView, attribute: .Right, multiplier: 1, constant: 0))
        userPictureImageView.addConstraint(NSLayoutConstraint(item: userNameInitialsLabel, attribute: .Top, relatedBy: .Equal, toItem: userPictureImageView, attribute: .Top, multiplier: 1, constant: 0))
        userPictureImageView.addConstraint(NSLayoutConstraint(item: userNameInitialsLabel, attribute: .Bottom, relatedBy: .Equal, toItem: userPictureImageView, attribute: .Bottom, multiplier: 1, constant: 0))
    }
}

extension String {
    var initials: String {
        get {
            return "".join(self.componentsSeparatedByString(" ").map {
                (component: String) -> String in
                return component.substringToIndex(advance(component.startIndex, 1))
            })
        }
    }
}

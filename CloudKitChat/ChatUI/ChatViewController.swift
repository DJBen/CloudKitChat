import UIKit
import CloudKit

let messageFontSize: CGFloat = 17
let toolBarMinHeight: CGFloat = 44
let textViewMaxHeight: (portrait: CGFloat, landscape: CGFloat) = (portrait: 272, landscape: 90)

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    let chatGroup: ChatGroup
    var tableView: UITableView!
    var toolBar: UIToolbar!
    var textView: UITextView!
    var sendButton: UIButton!
    var rotating = false
    private var messagesOrderedByTimePeriod = [[Message]]()
    
    override var inputAccessoryView: UIView! {
        get {
            if toolBar == nil {
                toolBar = UIToolbar(frame: CGRectMake(0, 0, 0, toolBarMinHeight-0.5))
                
                textView = InputTextView(frame: CGRectZero)
                textView.backgroundColor = UIColor(white: 250/255, alpha: 1)
                textView.delegate = self
                textView.font = UIFont.systemFontOfSize(messageFontSize)
                textView.layer.borderColor = UIColor(red: 200/255, green: 200/255, blue: 205/255, alpha:1).CGColor
                textView.layer.borderWidth = 0.5
                textView.layer.cornerRadius = 5
                textView.scrollsToTop = false
                textView.textContainerInset = UIEdgeInsetsMake(4, 3, 3, 3)
                toolBar.addSubview(textView)
                
                sendButton = UIButton.buttonWithType(.System) as UIButton
                sendButton.enabled = false
                sendButton.titleLabel!.font = UIFont.boldSystemFontOfSize(17)
                sendButton.setTitle("Send", forState: .Normal)
                sendButton.setTitleColor(UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1), forState: .Disabled)
                sendButton.setTitleColor(UIColor(red: 1/255, green: 122/255, blue: 255/255, alpha: 1), forState: .Normal)
                sendButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
                sendButton.addTarget(self, action: "sendAction", forControlEvents: UIControlEvents.TouchUpInside)
                toolBar.addSubview(sendButton)
                
                // Auto Layout allows `sendButton` to change width, e.g., for localization.
                textView.setTranslatesAutoresizingMaskIntoConstraints(false)
                sendButton.setTranslatesAutoresizingMaskIntoConstraints(false)
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .Left, relatedBy: .Equal, toItem: toolBar, attribute: .Left, multiplier: 1, constant: 8))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .Top, relatedBy: .Equal, toItem: toolBar, attribute: .Top, multiplier: 1, constant: 7.5))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .Right, relatedBy: .Equal, toItem: sendButton, attribute: .Left, multiplier: 1, constant: -2))
                toolBar.addConstraint(NSLayoutConstraint(item: textView, attribute: .Bottom, relatedBy: .Equal, toItem: toolBar, attribute: .Bottom, multiplier: 1, constant: -8))
                toolBar.addConstraint(NSLayoutConstraint(item: sendButton, attribute: .Right, relatedBy: .Equal, toItem: toolBar, attribute: .Right, multiplier: 1, constant: 0))
                toolBar.addConstraint(NSLayoutConstraint(item: sendButton, attribute: .Bottom, relatedBy: .Equal, toItem: toolBar, attribute: .Bottom, multiplier: 1, constant: -4.5))
            }
            return toolBar
        }
    }
    
    init(chatGroup: ChatGroup) {
        self.chatGroup = chatGroup
        super.init(nibName: nil, bundle: nil)
        title = chatGroup.displayName
    }
    
    required init(coder aDecoder: NSCoder) {
        // This initilaizer should never be called
        self.chatGroup = ChatGroup(recordID: CKRecordID(recordName: ChatGroupRecordType))
        super.init(coder: aDecoder)
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let whiteColor = UIColor.whiteColor()
        view.backgroundColor = whiteColor // fixes push animation
        
        tableView = UITableView(frame: view.bounds, style: .Plain)
        tableView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        tableView.backgroundColor = whiteColor
        let edgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: toolBarMinHeight, right: 0)
        tableView.contentInset = edgeInsets
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .Interactive
        tableView.estimatedRowHeight = 44
        tableView.separatorStyle = .None
        tableView.registerClass(MessageSentDateCell.self, forCellReuseIdentifier: NSStringFromClass(MessageSentDateCell))
        view.addSubview(tableView)
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "keyboardDidShow:", name: UIKeyboardDidShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "menuControllerWillHide:", name: UIMenuControllerWillHideMenuNotification, object: nil) // #CopyMessage
        
        generateTableViewDisplay()
    }
    
    override func viewDidAppear(animated: Bool)  {
        super.viewDidAppear(animated)
        tableView.flashScrollIndicators()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "newMessageArrived:", name: CloudKitChatNewMessageReceivedNotification, object: CloudKitManager.sharedManager)
    }
    
    override func viewWillDisappear(animated: Bool)  {
        super.viewWillDisappear(animated)
        Outboxes[chatGroup].draft = textView.text
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // This gets called a lot. Perhaps there's a better way to know when `view.window` has been set?
    override func viewDidLayoutSubviews()  {
        super.viewDidLayoutSubviews()
        
        if !Outboxes[chatGroup].draft.isEmpty {
            textView.text = Outboxes[chatGroup].draft
            Outboxes[chatGroup].draft = ""
            textViewDidChange(textView)
            textView.becomeFirstResponder()
        }
    }
    
    // #iOS8
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
    }
    
    func newMessageArrived(notification: NSNotification) {
        if !self.chatGroup.fetched() {
            return
        }
        let newMessages = (notification.userInfo![CloudKitChatNewMessagesKey]! as [Message]).filter {
            newMessage -> Bool in
            return newMessage.recipientGroup! == self.chatGroup && find(self.chatGroup.messages!, newMessage) == nil
        }
        self.chatGroup.messages! += newMessages
        self.updateTableViewPendingMessages(newMessages)
        tableViewScrollToBottomAnimated(true)
        AudioUtil.playMessageIncomingSound()
        AudioUtil.vibrate()
        CloudKitManager.sharedManager.markNewMessagesProcessed(newMessages)
    }
    
    // MARK: Table view data source
    func numberOfSectionsInTableView(tableView : UITableView) -> Int {
        return messagesOrderedByTimePeriod.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messagesOrderedByTimePeriod[section].count + 1 // for sent-date cell
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier(NSStringFromClass(MessageSentDateCell), forIndexPath: indexPath) as MessageSentDateCell
            let message = messagesOrderedByTimePeriod[indexPath.section][0]
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateStyle = .ShortStyle
            dateFormatter.timeStyle = .ShortStyle
            cell.sentDateLabel.text = dateFormatter.stringFromDate(message.timeSent!)
            return cell
        } else {
            let cellIdentifier = NSStringFromClass(MessageBubbleCell)
            var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as MessageBubbleCell!
            if cell == nil {
                cell = MessageBubbleCell(style: .Default, reuseIdentifier: cellIdentifier)
                
                // Add gesture recognizers #CopyMessage
                let action: Selector = "messageShowMenuAction:"
                let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: action)
                doubleTapGestureRecognizer.numberOfTapsRequired = 2
                cell.bubbleImageView.addGestureRecognizer(doubleTapGestureRecognizer)
                cell.bubbleImageView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: action))
            }
            let message = messagesOrderedByTimePeriod[indexPath.section][indexPath.row-1]
            cell.configureWithMessage(message)
            return cell
        }
    }
    
    // #iOS7 - not needed for #iOS8
    func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        if indexPath.row == 0 {
            return 31
        } else {
            let message = messagesOrderedByTimePeriod[indexPath.section][indexPath.row-1]
            let height = (message.body! as NSString).boundingRectWithSize(CGSize(width: 218, height: CGFloat.max), options: .UsesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont.systemFontOfSize(messageFontSize)], context: nil).height
            #if arch(x86_64) || arch(arm64)
                return ceil(height) + 24
                #else
                return CGFloat(ceilf(height.native) + 24)
            #endif
        }
    }
    
    // Reserve row selection #CopyMessage

    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        return nil
    }

    func textViewDidChange(textView: UITextView) {
        updateTextViewHeight()
        sendButton.enabled = textView.hasText()
    }
    
    func keyboardWillShow(notification: NSNotification) {
        let userInfo = notification.userInfo
        let frameNew = (userInfo![UIKeyboardFrameEndUserInfoKey] as NSValue).CGRectValue()
        let insetNewBottom = tableView.convertRect(frameNew, fromView: nil).height
        let insetOld = tableView.contentInset
        let insetChange = insetNewBottom - insetOld.bottom
        let overflow = tableView.contentSize.height - (tableView.frame.height-insetOld.top-insetOld.bottom)
        
        let duration = (userInfo![UIKeyboardAnimationDurationUserInfoKey] as NSNumber).doubleValue
        let animations: (() -> Void) = {
            if !(self.tableView.tracking || self.tableView.decelerating) {
                // Move content with keyboard
                if overflow > 0 {                   // scrollable before
                    self.tableView.contentOffset.y += insetChange
                    if self.tableView.contentOffset.y < -insetOld.top {
                        self.tableView.contentOffset.y = -insetOld.top
                    }
                } else if insetChange > -overflow { // scrollable after
                    self.tableView.contentOffset.y += insetChange + overflow
                }
            }
        }
        if duration > 0 {
            let options = UIViewAnimationOptions(UInt((userInfo![UIKeyboardAnimationCurveUserInfoKey] as NSNumber).integerValue << 16)) // http://stackoverflow.com/a/18873820/242933
            UIView.animateWithDuration(duration, delay: 0, options: options, animations: animations, completion: nil)
        } else {
            animations()
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        let userInfo = notification.userInfo
        let frameNew = (userInfo![UIKeyboardFrameEndUserInfoKey] as NSValue).CGRectValue()
        let insetNewBottom = tableView.convertRect(frameNew, fromView: nil).height
        
        // Inset `tableView` with keyboard
        let contentOffsetY = tableView.contentOffset.y
        tableView.contentInset.bottom = insetNewBottom
        tableView.scrollIndicatorInsets.bottom = insetNewBottom
        // Prevents jump after keyboard dismissal
        if (self.tableView.tracking || self.tableView.decelerating) {
            tableView.contentOffset.y = contentOffsetY
        }
        
        // This method will be called again when dismissal is nearly complete
        // In that situation the animation duration is 0 and the begin and end frame are the same
        // At view loading, it will be called manually, so I need to eliminate that too
        if (notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as NSNumber).doubleValue != 0 && !CGRectEqualToRect((notification.userInfo![UIKeyboardFrameBeginUserInfoKey] as NSValue).CGRectValue(), (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as NSValue).CGRectValue()) {
            tableViewScrollToBottomAnimated(true)
        }
    }
    
    private func updateTextViewHeight() {
        let oldHeight = textView.frame.height
        let maxHeight = UIInterfaceOrientationIsPortrait(interfaceOrientation) ? textViewMaxHeight.portrait : textViewMaxHeight.landscape
        var newHeight = min(textView.sizeThatFits(CGSize(width: textView.frame.width, height: CGFloat.max)).height, maxHeight)
        #if arch(x86_64) || arch(arm64)
            newHeight = ceil(newHeight)
            #else
            newHeight = CGFloat(ceilf(newHeight.native))
        #endif
        if newHeight != oldHeight {
            toolBar.frame.size.height = newHeight+8*2-0.5
        }
    }
    
    func sendAction() {
        // Autocomplete text before sending #hack
        textView.resignFirstResponder()
        textView.becomeFirstResponder()
        CurrentUser!.sendMessageWithBody(textView.text, toGroup: chatGroup, constructedMessage: {
            pendingMessage in
            Outboxes[self.chatGroup].addMessage(pendingMessage)
            self.updateTableViewPendingMessages([pendingMessage])
            }, completion: {
                message, error in
                if error != nil {
                    println("error sending message \"\(self.textView.text)\": \(error)")
                    return
                }
                let result = Outboxes[self.chatGroup].deleteMessage(message!)
        })
        
        textView.text = nil
        updateTextViewHeight()
        sendButton.enabled = false
        tableViewScrollToBottomAnimated(true)
        AudioUtil.playMessageOutgoingSound()
    }
    
    private func updateTableViewPendingMessages(pendingMessages: [Message]) {
        if pendingMessages.isEmpty {
            return
        }
        generateTableViewDisplay()
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        var messagesDict = [NSDate: [Message]]()
        
        tableView.beginUpdates()
        for pendingMessage in pendingMessages {
            let messageDateString = dateFormatter.stringFromDate(pendingMessage.timeSent!)
            let messageDate = dateFormatter.dateFromString(messageDateString)!
            
            for message in chatGroup.messages! + Outboxes[chatGroup].pendingMessages {
                if !message.fetched() || message == pendingMessage {
                    continue
                }
                let dateString = dateFormatter.stringFromDate(message.timeSent!)
                let date = dateFormatter.dateFromString(dateString)!
                if var messagesAtSameDay = messagesDict[date] {
                    messagesAtSameDay.append(message)
                    messagesDict[date] = messagesAtSameDay
                } else {
                    messagesDict[date] = [message]
                }
            }
            
            if var messagesAtSameDay = messagesDict[messageDate] {
                messagesAtSameDay.append(pendingMessage)
                messagesAtSameDay.sort { $0 < $1 }
                let row = find(messagesAtSameDay, pendingMessage)! + 1
                let sortedAllMessageDates = messagesDict.keys.array.sorted { $0.compare($1) as NSComparisonResult == .OrderedAscending }
                var section: Int!
                var index: Int = 0
                for otherMessageDate in sortedAllMessageDates {
                    if messageDate.compare(otherMessageDate) == .OrderedSame {
                        section = index
                        break
                    }
                    index++
                }
                tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: row, inSection: section)], withRowAnimation: .Automatic)
            } else {
                var allMessageDates = messagesDict.keys.array
                allMessageDates.append(messageDate)
                allMessageDates.sort { $0.compare($1) == .OrderedAscending }
                let section = find(allMessageDates, messageDate)!
                tableView.insertSections(NSIndexSet(index: section), withRowAnimation: .Automatic)
                tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: section)], withRowAnimation: .Automatic)
            }
        }
        tableView.endUpdates()
    }
    
    private func tableViewScrollToBottomAnimated(animated: Bool) {
        if tableView.numberOfSections() == 0 {
            return
        }
        let numberOfRows = tableView.numberOfRowsInSection(tableView.numberOfSections() - 1)
        if numberOfRows > 0 {
            tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: numberOfRows - 1, inSection: tableView.numberOfSections() - 1), atScrollPosition: .Bottom, animated: animated)
        }
    }
    
    /// Call this method to generate messages ordered by day to feed the table view
    private func generateTableViewDisplay() {
        if !chatGroup.fetched() {
            messagesOrderedByTimePeriod = [[Message]]()
        }
        var messagesDict = [NSDate: [Message]]()
        for message in chatGroup.messages! + Outboxes[chatGroup].pendingMessages {
            if !message.fetched() {
                println("Warning: message \(message) not fetched")
                continue
            }
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            let dateString = dateFormatter.stringFromDate(message.timeSent!)
            let date = dateFormatter.dateFromString(dateString)!
            if var messagesAtSameDay = messagesDict[date] {
                messagesAtSameDay.append(message)
                messagesDict[date] = messagesAtSameDay
            } else {
                messagesDict[date] = [message]
            }
        }
        let dates = messagesDict.keys.array.sorted { $0.compare($1) as NSComparisonResult == .OrderedAscending }
        var orderedMessages = [[Message]]()
        for distinctDate in dates {
            orderedMessages.append(messagesDict[distinctDate]!)
        }
        messagesOrderedByTimePeriod = orderedMessages
    }
    
    // Handle actions #CopyMessage
    // 1. Select row and show "Copy" menu
    func messageShowMenuAction(gestureRecognizer: UITapGestureRecognizer) {
        let twoTaps = (gestureRecognizer.numberOfTapsRequired == 2)
        let doubleTap = (twoTaps && gestureRecognizer.state == .Ended)
        let longPress = (!twoTaps && gestureRecognizer.state == .Began)
        if (doubleTap || longPress) {
            let pressedIndexPath = tableView.indexPathForRowAtPoint(gestureRecognizer.locationInView(tableView))
            tableView.selectRowAtIndexPath(pressedIndexPath!, animated: false, scrollPosition: .None)
            
            let menuController = UIMenuController.sharedMenuController()
            let bubbleImageView = gestureRecognizer.view!
            menuController.setTargetRect(bubbleImageView.frame, inView: bubbleImageView.superview!)
            menuController.menuItems = [UIMenuItem(title: "Copy", action: "messageCopyTextAction:")!]
            menuController.setMenuVisible(true, animated: true)
        }
    }
    // 2. Copy text to pasteboard
    func messageCopyTextAction(menuController: UIMenuController) {
        let selectedIndexPath = tableView.indexPathForSelectedRow()!
        let selectedMessage = messagesOrderedByTimePeriod[selectedIndexPath.section][selectedIndexPath.row-1]
        UIPasteboard.generalPasteboard().string = selectedMessage.body
    }
    // 3. Deselect row
    func menuControllerWillHide(notification: NSNotification) {
        tableView.deselectRowAtIndexPath(tableView.indexPathForSelectedRow()!, animated: false)
        (notification.object as UIMenuController).menuItems = nil
    }
}

// Only show "Copy" when editing `textView` #CopyMessage
class InputTextView: UITextView {
    override func canPerformAction(action: Selector, withSender sender: AnyObject!) -> Bool {
        if (delegate as ChatViewController).tableView.indexPathForSelectedRow() != nil {
            return action == "messageCopyTextAction:"
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    // More specific than implementing `nextResponder` to return `delegate`, which might cause side effects?
    func messageCopyTextAction(menuController: UIMenuController) {
        (delegate as ChatViewController).messageCopyTextAction(menuController)
    }
}

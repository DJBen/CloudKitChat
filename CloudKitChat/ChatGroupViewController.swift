//
//  ChatGroupViewController.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 7/29/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit

class ChatGroupViewController: UITableViewController {
    
    private var chats: [ChatGroup]? {
        get {
            return CurrentUser?.chatGroups ?? nil
        }
    }
    
    private var groupCount: Int {
        get {
            return self.chats?.count ?? 0
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = editButtonItem() // TODO: KVO
        tableView.registerClass(ChatCell.self, forCellReuseIdentifier: NSStringFromClass(ChatCell))
        
        // Add pull to refresh
        refreshControl = UIRefreshControl()
        refreshControl!.addTarget(self, action: "refreshChatGroups:", forControlEvents: .ValueChanged)
        
        let debugOptionsGR = UITapGestureRecognizer(target: self, action: "showDebugOptions:")
        debugOptionsGR.numberOfTapsRequired = 2
        debugOptionsGR.numberOfTouchesRequired = 2
        self.tableView.addGestureRecognizer(debugOptionsGR)
        
        if tableView.numberOfSections() != 0 && tableView.numberOfRowsInSection(0) != 0 {
            self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), atScrollPosition: .Top, animated: true)
        }
        refreshControl!.beginRefreshing()
        refreshChatGroupsWithCompletion {
            error in
            self.refreshControl!.endRefreshing()
            if error == nil {
                self.subscribeToMessageUpdateNotification()
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        refreshChatGroups(refreshControl)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "newMessageArrived:", name: CloudKitChatNewMessageReceivedNotification, object: CloudKitManager.sharedManager)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func unwindToChatGroupViewController(segue: UIStoryboardSegue) {
        if let findFriendsViewController = segue.sourceViewController as? FindFriendsViewController {
            if let newChatGroup = findFriendsViewController.chatGroupCreated {
                refreshChatGroups(refreshControl)
            }
        }
    }
    
    func newMessageArrived(notification: NSNotification) {
        if self.groupCount == 0 {
            return
        }
        let newMessages = notification.userInfo![CloudKitChatNewMessagesKey]! as [Message]
        // The flag indicating if the chat group is found (message sent to existing chat group).
        // If so, add the new message to its group
        // If not, refetch new group: a user just added you to his/her new group
        for newMessage in newMessages {
            for chatGroup in self.chats! {
                if !chatGroup.fetched() {
                    fatalError("Chat Group is not fetched.")
                    return
                }
                if newMessage.recipientGroup! == chatGroup  {
                    if find(chatGroup.messages!, newMessage) == nil {
                        // New messages are likely to be fetched twice
                        // Filter out those duplicates
                        chatGroup.messages!.append(newMessage)
                        break
                    }
                }
            }
        }
        self.tableView.reloadData()
        AudioUtil.vibrate()
        CloudKitManager.sharedManager.markNewMessagesProcessed(newMessages)
    }
    
    func showDebugOptions(sender: UIGestureRecognizer!) {
        let alertController = UIAlertController(title: "Debug Options", message: nil, preferredStyle: .ActionSheet)
        let completionNotifier = UIAlertController(title: "Debug Action Placeholder", message: "Placeholder", preferredStyle: .Alert)
        completionNotifier.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Reset Subscriptions", style: .Destructive) {
            _ in
            CloudKitManager.sharedManager.deleteAllSubscriptionsWithCompletion {
                error in
                if error != nil {
                    completionNotifier.title = "Unable to delete subscriptions"
                    completionNotifier.message = error!.localizedDescription
                    self.presentViewController(completionNotifier, animated: true, completion: nil)
                    return
                }
                CurrentUser!.subscribeToChatGroupAndMessageChangesWithCompletion {
                    error in
                    if error != nil {
                        completionNotifier.title = "Unable to subscribe"
                        completionNotifier.message = error!.localizedDescription
                        self.presentViewController(completionNotifier, animated: true, completion: nil)
                        return
                    }
                    completionNotifier.title = "Subscription Reset"
                    completionNotifier.message = "You have reset the subscriptions successfully."
                    self.presentViewController(completionNotifier, animated: true, completion: nil)
                }
            }
        })
        alertController.addAction(UIAlertAction(title: "Add Subscriptions", style: .Default) {
            _ in
            CurrentUser!.subscribeToChatGroupAndMessageChangesWithCompletion {
                error in
                if error != nil {
                    completionNotifier.title = "Unable to subscribe"
                    completionNotifier.message = error!.localizedDescription
                    self.presentViewController(completionNotifier, animated: true, completion: nil)
                    return
                }
                completionNotifier.title = "Add Subscription"
                completionNotifier.message = "You have added the subscriptions successfully."
                self.presentViewController(completionNotifier, animated: true, completion: nil)
            }
        })
        alertController.addAction(UIAlertAction(title: "Clear Subscriptions", style: .Default) {
            alertAction in
            CloudKitManager.sharedManager.deleteAllSubscriptionsWithCompletion {
                error in
                if error != nil {
                    completionNotifier.title = "Unable to delete subscription"
                    completionNotifier.message = error!.localizedDescription
                    self.presentViewController(completionNotifier, animated: true, completion: nil)
                    return
                }
                completionNotifier.title = "Subscription Cleared"
                completionNotifier.message = "You have cleared all subscriptions successfully."
                self.presentViewController(completionNotifier, animated: true, completion: nil)
            }
        })
        alertController.addAction(UIAlertAction(title: "Show Subscriptions", style: .Default) {
            alertAction in
            CloudKitManager.sharedManager.fetchAllSubscriptionsWithCompletion {
                subscriptions, error in
                if error != nil {
                    completionNotifier.title = "Unable to fetch subscriptions"
                    completionNotifier.message = error!.localizedDescription
                    self.presentViewController(completionNotifier, animated: true, completion: nil)
                    return
                }
                completionNotifier.title = String(format: "\(subscriptions!.count) Subscription%@", subscriptions!.count != 1 ? "s" : "")
                completionNotifier.message = subscriptions!.map {
                    subscription -> String in
                    return "{\(subscription.subscriptionID):  \(subscription.recordType), \(subscription.predicate), sOptions=\(subscription.subscriptionOptions.toRaw()), sType=\(subscription.subscriptionType.toRaw())}"
                }.reduce(String()) {
                    description1, description2 -> String in
                    if description1.isEmpty {
                        return description2
                    } else {
                        return description1 + ",\n" + description2
                    }
                }
                self.presentViewController(completionNotifier, animated: true, completion: nil)
            }
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupCount
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(NSStringFromClass(ChatCell), forIndexPath: indexPath) as ChatCell
        if let chatSession = chats?[indexPath.row] {
            cell.configureWithChatGroup(chatSession)
        }
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if chats != nil {
            let chatSession = chats![indexPath.row]
            let chatViewController = ChatViewController(chatGroup: chatSession)
            navigationController!.pushViewController(chatViewController, animated: true)
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView!, canEditRowAtIndexPath indexPath: NSIndexPath!) -> Bool {
        // Return NO if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView!, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath!) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView!, moveRowAtIndexPath fromIndexPath: NSIndexPath!, toIndexPath: NSIndexPath!) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView!, canMoveRowAtIndexPath indexPath: NSIndexPath!) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    func refreshChatGroups(sender: UIRefreshControl?) {
        if let refreshControl = sender {
            if tableView.numberOfSections() != 0 && tableView.numberOfRowsInSection(0) != 0 {
                self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), atScrollPosition: .Top, animated: true)
            }
            refreshControl.beginRefreshing()
        } else {
            SVProgressHUD.showWithStatus("Loading...", maskType: UInt(SVProgressHUDMaskTypeClear))
        }

        self.refreshChatGroupsWithCompletion {
            _ in
            if let refreshControl = sender {
                refreshControl.endRefreshing()
            } else {
                SVProgressHUD.dismiss()
            }
        }
    }
    
    private func refreshChatGroupsWithCompletion(completion: ((error: NSError?) -> Void)?) {
        CurrentUser!.fetchChatGroupsWithFullDetails(true) {
            groups, error in
            if error != nil {
                println("\(error)")
                completion?(error: error)
                return
            }
            self.tableView.reloadData()
            completion?(error: nil)
        }
    }
    
    private func subscribeToMessageUpdateNotification() {
        CurrentUser!.subscribeToChatGroupAndMessageChangesWithCompletion {
            error in
            if error != nil {
                println("Error subscribing \(error)")
                if !error!.isDuplicateSubscription() {
                    return
                }
            }
        }
    }
}

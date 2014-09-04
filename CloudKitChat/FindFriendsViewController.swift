//
//  FindFriendsViewController.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 8/23/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit

let ButtonCellReuseIdentifier = "discoveryCell"
let unwindToChatGroupSegueIdentifier = "unwindToChatGroup"

class FindFriendsViewController: UITableViewController, UITextFieldDelegate {
    
    private var friends = [User]()
    private var chosen = [User: Bool]()
    private var previousUserTypedGroupName = String()
    private var canCreateGroup: Bool {
        get {
            return chosen.values.array.filter {
                isUserChosen -> Bool in
                return isUserChosen
            }.count > 0
        }
    }
    private var chosenFriends: [User] {
        get {
            return chosen.keys.array.filter {
                user -> Bool in
                return self.chosen[user]!
            }
        }
    }
    private(set) var chatGroupCreated: ChatGroup?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem!.enabled = canCreateGroup
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func createChatGroup(sender: UIBarButtonItem!) {
        if let nameCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 1)) as? ChatGroupNameTableViewCell {
            if nameCell.chatGroupNameTextField.text.isEmpty {
                let alert = UIAlertController(title: "Empty Chat Name", message: "Please enter a name for your chat session.", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
                return
            }
            SVProgressHUD.showWithStatus("Creating chat...", maskType: UInt(SVProgressHUDMaskTypeClear))
            CurrentUser!.createChatGroupWithName(nameCell.chatGroupNameTextField.text, otherUsers: chosenFriends) {
                group, error in
                SVProgressHUD.dismiss()
                if error != nil {
                    println("Create chat group error \(error)")
                    let alert = UIAlertController(title: "Error Creating Chat", message: error!.localizedDescription, preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                    return
                }
                println("Create chat group \(group)")
                self.chatGroupCreated = group
                self.performSegueWithIdentifier(unwindToChatGroupSegueIdentifier, sender: self)
            }
        }
    }
    
    // MARK: Text field delegate
    
    func textFieldDidEndEditing(textField: UITextField!) {
        previousUserTypedGroupName = textField.text
        println("END")
    }
    
    func textFieldShouldReturn(textField: UITextField!) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 3
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        case 1:
            return "New Chat"
        case 2:
            return "Friends"
        default:
            return nil
        }
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        switch section {
        case 0:
            return 2
        case 1:
            return 1
        case 2:
            return friends.count
        default:
            return 0
        }
    }

    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier(ButtonCellReuseIdentifier, forIndexPath: indexPath) as UITableViewCell
            switch indexPath.row {
            case 0:
                cell.textLabel!.text = "Search friend by email"
            case 1:
                cell.textLabel!.text = "Search friends from contacts"
            default:
                return cell
            }
            return cell
        } else if indexPath.section == 1 {
            let groupNameCell = tableView.dequeueReusableCellWithIdentifier(ChatGroupNameTableViewCellIdentifier, forIndexPath: indexPath) as ChatGroupNameTableViewCell
            return groupNameCell
        } else if indexPath.section == 2 {
            let friendCell = tableView.dequeueReusableCellWithIdentifier(FriendTableViewCellIdentifier, forIndexPath: indexPath) as FriendTableViewCell
            let friend = friends[indexPath.row]
            friendCell.nameLabel.text = friend.name!
            if chosen[friend] == nil {
                chosen[friend] = false
            }
            friendCell.chosen = chosen[friend]!
            return friendCell
        }
        return UITableViewCell()
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                // Search friend by email
                return
            case 1:
                // Search friends from contacts
                SVProgressHUD.showWithStatus("Looking up contacts...", maskType: UInt(SVProgressHUDMaskTypeClear))
                CloudKitManager.sharedManager.discoverUsersFromContactWithCompletion {
                    users, error in
                    SVProgressHUD.dismiss()
                    if error != nil && !error!.isPartialError() {
                        return
                    }
                    println("Discovered users = \(users)")
                    self.friends += users!
                    self.tableView.reloadData()
                }
                return
            default:
                return
            }
        } else if indexPath.section == 2 {
            let friendCell = tableView.cellForRowAtIndexPath(indexPath) as FriendTableViewCell
            friendCell.toggle()
            let friend = friends[indexPath.row]
            chosen[friend] = friendCell.chosen
            self.navigationItem.rightBarButtonItem!.enabled = canCreateGroup
            
            // Auto-generate group name if there's only one person to chat with
            if let nameCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 1)) as? ChatGroupNameTableViewCell {
                if chosenFriends.count == 1 {
                    nameCell.chatGroupNameTextField.enabled = false
                    previousUserTypedGroupName = nameCell.chatGroupNameTextField.text
                    nameCell.chatGroupNameTextField.text = "(Inferred)"
                } else {
                    if !nameCell.chatGroupNameTextField.enabled {
                        nameCell.chatGroupNameTextField.enabled = true
                        nameCell.chatGroupNameTextField.text = previousUserTypedGroupName
                    }
                }
            }
        }
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 44
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

}

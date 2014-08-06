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
            return CloudKitManager.sharedManager.currentUser?.chatGroups ?? nil
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
        
//        refreshChatGroups()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return groupCount
    }

    
    override func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let cell = tableView.dequeueReusableCellWithIdentifier(NSStringFromClass(ChatCell), forIndexPath: indexPath) as ChatCell
        if let chat = chats?[indexPath.row] {
            cell.configureWithChatGroup(chat)
        }
        return cell
    }

    override func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        if chats != nil {
            let chat = chats![indexPath.row]
            let chatViewController = ChatViewController(chatGroup: chat)
            navigationController.pushViewController(chatViewController, animated: true)
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

    
    private func refreshChatGroups() {
        if let currentUser = CloudKitManager.sharedManager.currentUser {
            currentUser.fetchChatGroupsWithCompletion {
                groups, error in
                if error != nil {
                    println("\(error)")
                    return
                }
                self.tableView.reloadData()
                println("chatgroups: \(currentUser.chatGroups)")
            }
        } else {
            // TODO: Error handling
        }
    }
}

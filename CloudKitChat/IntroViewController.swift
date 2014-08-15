//
//  IntroViewController.swift
//  CloudKitChat
//
//  Created by Sihao Lu on 7/29/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

import UIKit
import CloudKit

let ChatGroupViewControllerSegueName = "ChatGroupViewControllerSegue"

class IntroViewController: UIViewController, UITextFieldDelegate {
    
    private enum KeyboardEvent {
        case Show(CGFloat)
        case Hide
    }
    
    @IBOutlet weak var cloudImageView: UIImageView!
    @IBOutlet weak var cloudKitChatTitleLabel: UILabel!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var askForNameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!

    var lookUpContactsButtonContainer: UIVisualEffectView!
    var goToChatsButtonContainer: UIVisualEffectView!
    var discoverUserNameButtonContainer: UIVisualEffectView!
    var proceedButtonContainer: UIVisualEffectView!
    var goBackButtonContainer: UIVisualEffectView!
    var activeTextField: UITextField?
    
    let textFieldKeyboardDistance: CGFloat = 20
    
    var buttonContainers: [UIVisualEffectView!] {
    get {
        return [lookUpContactsButtonContainer, goToChatsButtonContainer, discoverUserNameButtonContainer, proceedButtonContainer, goBackButtonContainer]
    }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViewsAndConstraints()
        fetchUserAndLogin()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        registerForKeyboardNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        unregisterForKeyboardNotifications()
    }
    
    // MARK: Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    
    // MARK: Events
    func lookUpContactsTapped(sender: UIButton!) {
        CloudKitManager.sharedManager.requestDiscoveryPermission {
            discoverable, error in
            if error != nil {
                println("Discover error: \(error)")
                let alert = UIAlertController(title: "Unable to discover", message: "Please try again.", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
                return
            }
            println("Discover enabled: \(discoverable)")
            CloudKitManager.sharedManager.discoverUsersFromContactWithCompletion {
                users, error in
                println("\(users), \(error)")
            }
        }
    }

    func goToChatsTapped(sender: UIButton!) {
        
    }
    
    func discoverUserNameTapped(sender: UIButton!) {
        println("Discover user name")
        activeTextField?.resignFirstResponder()
        SVProgressHUD.showWithMaskType(UInt(SVProgressHUDMaskTypeClear))
        CloudKitManager.sharedManager.requestDiscoveryPermission {
            discoverable, error in
            if error != nil {
                let alert = UIAlertController(title: "Unable to contact iCloud", message: "Please try again.", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
                SVProgressHUD.dismiss()
                return
            }
            if !discoverable {
                let alert = UIAlertController(title: "Unable to retreive user name.", message: "Please turn on iCloud discover.", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
                SVProgressHUD.dismiss()
                return
            }
            User.fetchUserWithNameDiscovered(true) {
                user, error in
                SVProgressHUD.dismiss()
                println("\(user), \(error)")
                if user != nil && user!.fetched() {
                    self.nameTextField.text = user!.name
                }
                if error != nil {
                    
                }
            }
        }
    }
    
    func proceedTapped(sender: UIButton!) {
        activeTextField?.resignFirstResponder()
        if nameTextField.text.lengthOfBytesUsingEncoding(NSUnicodeStringEncoding) == 0 {
            let alert = UIAlertController(title: "You are anonymous", message: "Please enter your name.", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        self.scrollView.setContentOffset(CGPoint(x: UIScreen.mainScreen().bounds.width, y: 0), animated: true)
    }
    
    func goBackTapped(sender: UIButton!) {
        self.scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
    }

    // MARK: Text Field delegate
    func textFieldDidBeginEditing(textField: UITextField!) {
        activeTextField = textField
    }
    
    func textFieldDidEndEditing(textField: UITextField!) {
        activeTextField = nil
    }
    
    func textFieldShouldReturn(textField: UITextField!) -> Bool {
        animateContentViewForKeyboardEvent(.Hide)
        textField.resignFirstResponder()
        return false
    }
    
    // MARK: Private methods

    private func registerForKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardDidShowNotification, object: nil, queue: NSOperationQueue.mainQueue()) {
            notification in
            let keyboardSize = notification.userInfo[UIKeyboardFrameBeginUserInfoKey]!.CGRectValue().size
            if self.activeTextField != nil {
                let textFieldBottomY = self.view.convertPoint(self.activeTextField!.frame.origin, fromView: self.scrollView).y + self.activeTextField!.bounds.size.height
                let offset: CGFloat = textFieldBottomY + self.textFieldKeyboardDistance - (UIScreen.mainScreen().bounds.height - keyboardSize.height)
                if offset > 0 {
                    self.animateContentViewForKeyboardEvent(.Show(offset))
                }
            } else {
                self.animateContentViewForKeyboardEvent(.Show(keyboardSize.height))
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardWillHideNotification, object: nil, queue: NSOperationQueue.mainQueue()) {
            notification in
            self.animateContentViewForKeyboardEvent(.Hide)
        }
    }
    
    private func unregisterForKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
    }
    
    private func animateContentViewForKeyboardEvent(event: KeyboardEvent) {
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .BeginFromCurrentState, animations: {
            switch event {
            case .Show(let offset):
                self.contentView.frame.origin = CGPoint(x: 0, y: -offset)
            case .Hide:
                self.contentView.frame.origin = CGPoint(x: 0, y: 0)
            }
            }, completion: nil)
    }
    
    private func setUpViewsAndConstraints() {
        let screenWidth = UIScreen.mainScreen().bounds.width
        scrollView.contentSize.width = 2 * screenWidth
        
        let blurEffect = UIBlurEffect(style: .ExtraLight)
        lookUpContactsButtonContainer = UIVisualEffectView(effect: blurEffect)
        goToChatsButtonContainer = UIVisualEffectView(effect: blurEffect)
        discoverUserNameButtonContainer = UIVisualEffectView(effect: blurEffect)
        proceedButtonContainer = UIVisualEffectView(effect: blurEffect)
        goBackButtonContainer = UIVisualEffectView(effect: blurEffect)
        
        for buttonContainer in buttonContainers {
            buttonContainer.layer.cornerRadius = 7
            buttonContainer.layer.masksToBounds = true
            buttonContainer.setTranslatesAutoresizingMaskIntoConstraints(false)
            self.scrollView.addSubview(buttonContainer)
        }
        let constraints: [NSLayoutConstraint] = [
            NSLayoutConstraint(item: discoverUserNameButtonContainer, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 184),
            NSLayoutConstraint(item: discoverUserNameButtonContainer, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 30),
            NSLayoutConstraint(item: discoverUserNameButtonContainer, attribute: .Top, relatedBy: .Equal, toItem: nameTextField, attribute: .Bottom, multiplier: 1, constant: 25),
            NSLayoutConstraint(item: discoverUserNameButtonContainer, attribute: .CenterX, relatedBy: .Equal, toItem: self.scrollView, attribute: .CenterX, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: lookUpContactsButtonContainer, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 190),
            NSLayoutConstraint(item: lookUpContactsButtonContainer, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 30),
            NSLayoutConstraint(item: lookUpContactsButtonContainer, attribute: .CenterX, relatedBy: .Equal, toItem: self.scrollView, attribute: .CenterX, multiplier: 3, constant: 0),
            NSLayoutConstraint(item: goToChatsButtonContainer, attribute: .CenterY, relatedBy: .Equal, toItem: goBackButtonContainer, attribute: .CenterY, multiplier: 1, constant: 23),
            NSLayoutConstraint(item: lookUpContactsButtonContainer, attribute: .CenterY, relatedBy: .Equal, toItem: goBackButtonContainer, attribute: .CenterY, multiplier: 1, constant: -23),
            NSLayoutConstraint(item: goToChatsButtonContainer, attribute: .Leading, relatedBy: .Equal, toItem: lookUpContactsButtonContainer, attribute: .Leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: goToChatsButtonContainer, attribute: .Trailing, relatedBy: .Equal, toItem: lookUpContactsButtonContainer, attribute: .Trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: goToChatsButtonContainer, attribute: .Height, relatedBy: .Equal, toItem: lookUpContactsButtonContainer, attribute: .Height, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: proceedButtonContainer, attribute: .CenterY, relatedBy: .Equal, toItem: nameTextField, attribute: .CenterY, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: proceedButtonContainer, attribute: .Height, relatedBy: .Equal, toItem: proceedButtonContainer, attribute: .Width, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: proceedButtonContainer, attribute: .Height, relatedBy: .Equal, toItem: nameTextField, attribute: .Height, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: proceedButtonContainer, attribute: .Left, relatedBy: .Equal, toItem: nameTextField, attribute: .Right, multiplier: 1, constant: 15),
            NSLayoutConstraint(item: goBackButtonContainer, attribute: .Left, relatedBy: .Equal, toItem: self.scrollView, attribute: .CenterX, multiplier: 2, constant: 20),
            NSLayoutConstraint(item: goBackButtonContainer, attribute: .Height, relatedBy: .Equal, toItem: nameTextField, attribute: .Height, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: goBackButtonContainer, attribute: .Height, relatedBy: .Equal, toItem: goBackButtonContainer, attribute: .Width, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: goBackButtonContainer, attribute: .CenterY, relatedBy: .Equal, toItem: proceedButtonContainer, attribute: .CenterY, multiplier: 1, constant: 0)
        ]
        self.scrollView.addConstraints(constraints)
        
        let vibrancyEffect = UIVibrancyEffect(forBlurEffect: blurEffect)
        let lookUpContactsVibrancyEffectView = vibrancyEffectView(forBlurEffectView: lookUpContactsButtonContainer)
        lookUpContactsButtonContainer.contentView.addSubview(lookUpContactsVibrancyEffectView)
        let lookUpContactsButton: UIButton = UIButton.buttonWithType(.System) as UIButton
        lookUpContactsButton.setTitle("Find friends from contacts", forState: .Normal)
        lookUpContactsButton.addTarget(self, action: "lookUpContactsTapped:", forControlEvents: .TouchUpInside)
        lookUpContactsButton.frame = lookUpContactsButtonContainer.bounds
        lookUpContactsButton.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        lookUpContactsVibrancyEffectView.contentView.addSubview(lookUpContactsButton)
        
        let goToChatsVibrancyEffectView = vibrancyEffectView(forBlurEffectView: goToChatsButtonContainer)
        goToChatsButtonContainer.contentView.addSubview(goToChatsVibrancyEffectView)
        let goToChatsButton: UIButton = UIButton.buttonWithType(.System) as UIButton
        goToChatsButton.setTitle("Go to chat", forState: .Normal)
        goToChatsButton.addTarget(self, action: "goToChatsTapped:", forControlEvents: .TouchUpInside)
        goToChatsButton.frame = goToChatsVibrancyEffectView.bounds
        goToChatsButton.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        goToChatsVibrancyEffectView.contentView.addSubview(goToChatsButton)
        
        let discoverVibrancyEffectView = vibrancyEffectView(forBlurEffectView: discoverUserNameButtonContainer)
        discoverUserNameButtonContainer.contentView.addSubview(discoverVibrancyEffectView)
        let discoverUserNameButton: UIButton = UIButton.buttonWithType(.System) as UIButton
        discoverUserNameButton.setTitle("Use my iCloud name", forState: .Normal)
        discoverUserNameButton.addTarget(self, action: "discoverUserNameTapped:", forControlEvents: .TouchUpInside)
        discoverUserNameButton.frame = discoverVibrancyEffectView.bounds
        discoverUserNameButton.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        discoverVibrancyEffectView.contentView.addSubview(discoverUserNameButton)
        
        let proceedVibrancyEffectView = vibrancyEffectView(forBlurEffectView: proceedButtonContainer)
        proceedButtonContainer.contentView.addSubview(proceedVibrancyEffectView)
        let proceedButton: UIButton = UIButton.buttonWithType(.System) as UIButton
        proceedButton.setBackgroundImage(UIImage(named: "Play"), forState: .Normal)
        proceedButton.addTarget(self, action: "proceedTapped:", forControlEvents: .TouchUpInside)
        proceedButton.frame = proceedVibrancyEffectView.bounds
        proceedButton.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        proceedVibrancyEffectView.contentView.addSubview(proceedButton)
        
        let goBackVibrancyEffectView = vibrancyEffectView(forBlurEffectView: goBackButtonContainer)
        goBackButtonContainer.contentView.addSubview(goBackVibrancyEffectView)
        let goBackButton: UIButton = UIButton.buttonWithType(.System) as UIButton
        goBackButton.setBackgroundImage(UIImage(named: "Back"), forState: .Normal)
        goBackButton.addTarget(self, action: "goBackTapped:", forControlEvents: .TouchUpInside)
        goBackButton.frame = goBackVibrancyEffectView.bounds
        goBackButton.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        goBackVibrancyEffectView.contentView.addSubview(goBackButton)
    }
    
    private func vibrancyEffectView(forBlurEffectView blurEffectView:UIVisualEffectView) -> UIVisualEffectView {
        let vibrancy = UIVibrancyEffect(forBlurEffect: blurEffectView.effect as UIBlurEffect)
        let vibrancyView = UIVisualEffectView(effect: vibrancy)
        vibrancyView.frame = blurEffectView.bounds
        vibrancyView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        return vibrancyView
    }
    
    private func fetchUserAndLogin() {
        SVProgressHUD.showWithMaskType(UInt(SVProgressHUDMaskTypeClear))
        CloudKitManager.sharedManager.fetchUserWithNameDiscovered(false) {
            user, error in
            SVProgressHUD.dismiss()
            if error != nil {
                println("Fetch user error: \(error)")
                let alert = UIAlertController(title: "Unable to log you in", message: "Please try again.", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
                return
            }
            if user!.fetched() {
                // User has logged in before
                self.nameTextField.text = user!.name!
                self.performSegueWithIdentifier(ChatGroupViewControllerSegueName, sender: self)
            } else {
                // First time user login
                // TODO: Need to display a retry button
            }
        }
    }
}

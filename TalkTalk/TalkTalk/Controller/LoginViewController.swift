//
//  ViewController.swift
//  TalkTalk
//
//  Created by WuKaipeng on 14/12/17.
//  Copyright © 2017 WuKaipeng. All rights reserved.
//

import UIKit
import Firebase

class LoginViewController: UIViewController {

    //IBOutlet properties
    @IBOutlet weak var usernameField: FancyField!
    
    //Properties
    private lazy var userRef: DatabaseReference = Database.database().reference().child("users")
    private lazy var onlineUsersRef: DatabaseReference = Database.database().reference().child("onlineUsers")
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    /**
     * Login anonymously and update the user and online user data on Firebase
     *
     */
    @IBAction func loginButtonPressed(_ sender: Any) {
        if let userName = usernameField?.text {
            //login user anonymously
            Auth.auth().signInAnonymously(completion: { (user, error) in
                if let err = error {
                    print(err.localizedDescription)
                    return
                }
                let userItem = [
                    "name": "\(userName)"
                ]
                //update user data
                self.userRef.child("\(user!.uid)").updateChildValues(userItem, withCompletionBlock: { (error, ref) in
                    if let err = error {
                        print(err.localizedDescription)
                        return
                    }
                    //update online user data
                    self.onlineUsersRef.child("\(user!.uid)").updateChildValues(userItem)
                    let currentUser = User(id: (user?.uid)!, name: userName)
                    self.performSegue(withIdentifier: "toOnlineUsersVC", sender: currentUser)
                })
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let user = sender as? User {
            //pass the current user data
            let navVC = segue.destination as! UINavigationController
            let onlineUsersVC = navVC.viewControllers.first as! OnlineUsersViewController
            onlineUsersVC.currentUser = user
        }
    }
}


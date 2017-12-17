//
//  OnlineUsersViewController.swift
//  TalkTalk
//
//  Created by WuKaipeng on 16/12/17.
//  Copyright © 2017 WuKaipeng. All rights reserved.
//

import UIKit
import Firebase

class OnlineUsersViewController: UITableViewController {
    
    //Properties
    var currentUser: User?
    private var users: [User] = []
    private var onlineUsersRefHandle: DatabaseHandle?
    private lazy var usersRef: DatabaseReference = Database.database().reference().child("users")
    private lazy var onlineUsersRef: DatabaseReference = Database.database().reference().child("onlineUsers")
    private lazy var chatroomRef: DatabaseReference = Database.database().reference().child("chatrooms")
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Users"
        
        //Retrieve data of users from database
        observeOnlineUsers()
    }
    
    deinit {
        if let refHandle = onlineUsersRefHandle {
            onlineUsersRef.removeObserver(withHandle: refHandle)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let user = users[indexPath.row]
        print (user)
        if let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath) as? UserCell{
            //Pass the user object and let the cell configure its label
            cell.configureCell(user: user)
            return cell
        } else {
            return UserCell()
        }
    }
    
    /**
     * Retrieve all current users data from database and display the users on the tableview
     * This method will continue to retrieve new user data
     */
    private func observeOnlineUsers() {
        onlineUsersRefHandle = onlineUsersRef.observe(.childAdded, with: { (snapshot) -> Void in
            let userData = snapshot.value as! Dictionary<String, AnyObject>
            let id = snapshot.key
            if let name = userData["name"] as? String{
                self.users.append(User(id: id, name: name))
                self.tableView.reloadData()
            } else {
                print("Could not retrieve user data for user with ID: \(id)")
            }
        })
    }
    
    /**
     * Upon selecting an user on the tableview, this method will retrieve the chatroom ID
     * if the chatroom already exists, else it will create a new chatroom between these
     * two users and add the new chatroom to both users' list in the database
     */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = users[(indexPath as NSIndexPath).row]
        
        //retrieve data from the current user's friend list
        usersRef.child("\(currentUser!.id)").child("friends").child("\(user.id)").observeSingleEvent(of: .value) { (snapshot) in
            
            //if there is data, meaning that the two users have talked before
            if snapshot.exists(){
                //obtain the chatroom ID and perform segue
                if let chatroomID = snapshot.value{
                    self.performSegue(withIdentifier: "toChatroom", sender: ["user":user, "chatroomID":chatroomID])
                }
            } else {
                //if the two users have not talked before, create a chatroom
                let newChatroomRef = self.chatroomRef.childByAutoId()
                let chatroomItem = [
                    "chatroomName": "\(self.currentUser!.name)\(user.name)"
                ]
                newChatroomRef.setValue(chatroomItem, withCompletionBlock: { (error, ref) in
                    if let err = error {
                        print(err.localizedDescription)
                        return
                    }
                    
                    //Add chatroom to each other's friend list and perform segue
                    let id = newChatroomRef.key
                    self.usersRef.child("\(self.currentUser!.id)").child("friends").updateChildValues(["\(user.id)" : id])
                    self.usersRef.child("\(user.id)").child("friends").updateChildValues(["\(self.currentUser!.id)" : id])
                    self.performSegue(withIdentifier: "toChatroom", sender: ["user":user, "chatroomID":id])
                })
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let infoDict = sender as? [String:Any] {
            
            //obtain the user object
            let user = infoDict["user"] as! User
            
            //obtain the chatroom ID
            let chatroomID = infoDict["chatroomID"] as! String
            
            //pass data to the chatroom viewcontroller
            let chatroomVC = segue.destination as! ChatroomViewController
            chatroomVC.chatroomID = chatroomID
            chatroomVC.currentUser = currentUser
            chatroomVC.chatFriend = user
            chatroomVC.chatRef = chatroomRef.child(chatroomID)
        }
    }

}

//
//  ChatroomViewController.swift
//  TalkTalk
//
//  Created by WuKaipeng on 16/12/17.
//  Copyright © 2017 WuKaipeng. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import Firebase

class ChatroomViewController: JSQMessagesViewController {

    //Properties
    var chatroomID : String?
    var currentUser : User?
    var chatRef: DatabaseReference?
    var chatFriend: User? {
        didSet {
            title = chatFriend?.name
        }
    }
    var messages = [JSQMessage]()
    
    //properties for setting the chat bubbles
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    //Firebase reference for retreieve message data
    private lazy var messageRef: DatabaseReference = self.chatRef!.child("messages")
    private var messageRefHandle: DatabaseHandle?
    
    //Firebase reference for checking user typing
    private lazy var typingRef: DatabaseReference =
        self.chatRef!.child("typing").child(senderId())
    private lazy var typingQuery: DatabaseQuery = self.chatRef!.child("typing").queryOrderedByValue().queryEqual(toValue: true)
    
    //Firebase refernece for checking has message been read
    private lazy var messageReadRef: DatabaseReference =
        self.chatRef!.child("messageRead").child(chatFriend!.id)
    private var messageReadRefHandle: DatabaseHandle?
    private lazy var sendLastMessageRef: DatabaseReference =
        self.chatRef!.child("messageRead").child(currentUser!.id)
    private var sendLastMessageRefHandle: DatabaseHandle?
    
    private var currentUserTyping = false
    var isTyping: Bool {
        get {
            return currentUserTyping
        }
        set {
            currentUserTyping = newValue
            typingRef.setValue(newValue)
        }
    }
    
    var lastMessageHasRead : Bool?
    var lastMessageIndex: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //Remove Avatar
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        //setup to observe incoming message
        observeIncomingMessages()
        
        //remove attachment button
        inputToolbar.contentView?.leftBarButtonItem = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //Observe to retrieve user typing data
        observeUserTyping()
        
        //Observe to check last sent message ID
        observeLastMessageId()
        
        //Observe to check whether last send message has been read
        observeLastMessageRead()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        //remove the observers when user leaves the chatroom
        messageReadRef.removeAllObservers()
        sendLastMessageRef.removeAllObservers()
    }
    
    deinit {
        if let refHandle = messageReadRefHandle {
            messageReadRef.removeObserver(withHandle: refHandle)
        }
    }
    
    override func senderId() -> String {
        return currentUser!.id
    }
    
    override func senderDisplayName() -> String {
        return currentUser!.name
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView, messageDataForItemAt indexPath: IndexPath) -> JSQMessageData {
        return messages[indexPath.row]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    /**
     * Avatar item for each message, return nil since there is no avatar
     *
     * @return nil
     */
    override func collectionView(_ collectionView: JSQMessagesCollectionView, avatarImageDataForItemAt indexPath: IndexPath) -> (JSQMessageAvatarImageDataSource!) {
        return nil
    }
    
    /**
     * Bubble image for each message in the chatroom
     *
     */
    override func collectionView(_ collectionView: JSQMessagesCollectionView, messageBubbleImageDataForItemAt indexPath: IndexPath) -> JSQMessageBubbleImageDataSource? {
        let message = messages[indexPath.item]
        
        //if message is sent by current user, set the outgoging bubble
        if message.senderId == senderId() {
            return outgoingBubbleImageView
        } else {
            //if message is received, set incoming bubble
            return incomingBubbleImageView
        }
    }
    
    /**
     * Method to set the incoming and outgoing message text colour
     *
     */
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        
        //if message is outgoing, set text colour to white
        if message.senderId == senderId() {
            cell.textView?.textColor = UIColor.white
        } else {
            //if message is received, set text colour to black
            cell.textView?.textColor = UIColor.black
        }
        return cell
    }
    
    /**
     * Triggers when user presses the send button, it uploads the message data to the database
     *
     */
    override func didPressSend(_ button: UIButton, withMessageText text: String, senderId: String, senderDisplayName: String, date: Date) {
        
        //create a new message item
        let messageItemRef = messageRef.childByAutoId()
        let messageItem = [
            "senderId": senderId,
            "senderName": senderDisplayName,
            "text": text
        ]
        
        //upload message item to Firebase database
        messageItemRef.setValue(messageItem)
        
        //create item to track message has been read
        let messageReadItem: [String : Any] = [
            "hasRead" : false,
            "lastMessageId" : messageItemRef.key
            ]
        
        //update message read data to Firebase database
        self.chatRef!.child("messageRead").child(self.senderId()).setValue(messageReadItem)
        finishSendingMessage()
        
        isTyping = false
    }
    
    /**
     * Determine whether the current user is typing and update the value
     *
     */
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        
        isTyping = textView.text != ""
    }
    
    /**
     * Display the read label under the last send message that has been read
     *
     */
    override func collectionView(_ collectionView: JSQMessagesCollectionView, attributedTextForCellBottomLabelAt indexPath: IndexPath) -> NSAttributedString? {
        
        if let hasRead = lastMessageHasRead{
            //if the message has been read
            if indexPath.row == lastMessageIndex && hasRead {
                //set the label to read
                return NSAttributedString(string: "read")
            } else {
                //set the label to empty string
                return NSAttributedString(string: "")
            }
        }
        return NSAttributedString(string: "")

    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout, heightForCellBottomLabelAt indexPath: IndexPath) -> CGFloat {
        return 20.0
    }
    
    private func setupOutgoingBubble()-> JSQMessagesBubbleImage{
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    /**
     * Add a message item to the message array
     *
     * @param id Sender ID of the message
     * @param name Display name of the sender
     * @param text Message content
     */
    private func addMessage(withId id: String, name: String, text: String) {
        let message = JSQMessage(senderId: id, displayName: name, text: text)
        messages.append(message)
    }
    
    /**
     * Observe past messages of the chatroom and any new message
     *
     */
    private func observeIncomingMessages() {
        
        //Query the last 20 messages of the chatroom if there is any
        let messageQuery = messageRef.queryLimited(toLast:20)
        
        messageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if snapshot.exists(){
                
                //create the message item and append to the message array
                let message = snapshot.value as! Dictionary<String, String>
                if let id = message["senderId"] as String!, let senderName = message["senderName"] as String!, let messageText = message["text"] as String!, messageText.characters.count > 0 {
                    self.addMessage(withId: id, name: senderName, text: messageText)
                    
                    //Keep tracking of the index of the last sent message by current user
                    if id == self.senderId() {
                        self.lastMessageIndex = self.messages.count - 1
                    }
                    self.finishReceivingMessage()
                } else {
                    print("Could not retrieve message data")
                }
            }
        })
    }
    
    /**
     * Retrieve user typing data from database
     *
     */
    private func observeUserTyping() {
        let chatroomTypingRef = chatRef!.child("typing")
        typingRef = chatroomTypingRef.child(senderId())
        typingRef.onDisconnectRemoveValue()
        
        typingQuery.observe(.value) { (snapshot: DataSnapshot) in
            //if there is a user typing and the user is the current user, do nothing
            if snapshot.childrenCount == 1 && self.isTyping {
                return
            }
            
            //Display the typing indicator if chatting friend is typing
            self.showTypingIndicator = snapshot.childrenCount > 0
            self.scrollToBottom(animated: true)
        }
    }
    
    /**
     * Observe the last sent message and set the corresponding hasRead property to true
     * because the message is displayed on the current user's screen
     */
    private func observeLastMessageId(){
        messageReadRefHandle = messageReadRef.observe(.value) { (snapshot) in
            if snapshot.exists(){
                //set hasRead of the last send message to true
                self.messageReadRef.child("hasRead").setValue(true)
            }
        }
    }
    
    /**
     * Retrieve the last sent message data and determine whether the message has been read
     *
     */
    private func observeLastMessageRead(){
        sendLastMessageRefHandle = sendLastMessageRef.observe(.value, with: { (snapshot) in
            if snapshot.exists(){
                
                //retrieve message has read data and reload the collection view
                let infoDict = snapshot.value as! Dictionary<String, Any>
                self.lastMessageHasRead = infoDict["hasRead"] as? Bool
                self.collectionView?.reloadData()
            }
        })
    }

}

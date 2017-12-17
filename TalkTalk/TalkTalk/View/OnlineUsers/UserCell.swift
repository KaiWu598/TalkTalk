//
//  UserCell.swift
//  TalkTalk
//
//  Created by WuKaipeng on 16/12/17.
//  Copyright © 2017 WuKaipeng. All rights reserved.
//

import UIKit

class UserCell: UITableViewCell {

    @IBOutlet weak var username: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    /**
     * Configure the label on the cell to the user's username
     *
     * @param user User object containing the user information
     */
    func configureCell(user: User){
        username.text = user.name
    }


}

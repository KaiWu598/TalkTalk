//
//  FancyTextfield.swift
//  TalkTalk
//
//  Created by WuKaipeng on 16/12/17.
//  Copyright © 2017 WuKaipeng. All rights reserved.
//

import UIKit

class FancyField: UITextField {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        //add shadow effects to the textfield
        layer.shadowColor = UIColor(red: 120 / 255.0, green: 120 / 255.0, blue: 120 / 255.0, alpha: 0.6).cgColor
        layer.shadowOpacity = 0.8
        layer.shadowRadius = 5.0
        layer.shadowOffset = CGSize(width: 0.5, height: 0.5)
        layer.cornerRadius = 2
    }
}

//
//  SKIndicatorView.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/5/26.
//  Copyright © 2016年 Riven. All rights reserved.
//

class SKIndicatorView: UIActivityIndicatorView {
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        activityIndicatorViewStyle = .WhiteLarge
    }
}

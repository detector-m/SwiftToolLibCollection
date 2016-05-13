//
//  WhisperView.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/5/13.
//  Copyright © 2016年 Riven. All rights reserved.
//

import UIKit

public protocol NotificationControllerDelegate: class {
    func notificationControllerWillHide()
}

public class WhisperView: UIView {
    struct Dimensions {
        static let height: CGFloat = 24
        static let offsetHeight: CGFloat = height * 2
        static let imageSize: CGFloat = 14
        static let loaderTitleOffset: CGFloat = 5
    }
    
    
}

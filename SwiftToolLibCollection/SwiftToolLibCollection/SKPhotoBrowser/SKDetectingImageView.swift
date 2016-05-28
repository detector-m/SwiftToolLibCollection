//
//  SKDetectingImageView.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/5/26.
//  Copyright © 2016年 Riven. All rights reserved.
//

@objc protocol SKDetectingImageViewDelegate {
    func handleImageViewSingleTap(touchPoint: CGPoint)
    func handleImageViewDoubleTap(touchPoint: CGPoint)
}

class SKDetectingImageView: UIImageView {
    weak var delegate: SKDetectingImageViewDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        userInteractionEnabled = true
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 1
        self.addGestureRecognizer(doubleTap)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.numberOfTouchesRequired = 1
        singleTap.requireGestureRecognizerToFail(doubleTap)
        self.addGestureRecognizer(singleTap)
    }
    
    func handleDoubleTap(recognizer: UITapGestureRecognizer) {
        delegate?.handleImageViewDoubleTap(recognizer.locationInView(self))
    }
    
    func handleSingleTap(recognizer: UITapGestureRecognizer) {
    delegate?.handleImageViewSingleTap(recognizer.locationInView(self))
    }
}
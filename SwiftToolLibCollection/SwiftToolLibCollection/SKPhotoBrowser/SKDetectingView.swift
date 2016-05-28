//
//  SKDetectingView.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/5/26.
//  Copyright © 2016年 Riven. All rights reserved.
//

@objc protocol SKDetectingViewDelegate {
    func handleSingleTap(view: UIView, touch: UITouch)
    func handleDoubleTap(view: UIView, touch: UITouch)
}

class SKDetectingView: UIView {
    weak var delegate: SKDetectingViewDelegate?
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesEnded(touches, withEvent: event)
        
        let touch = touches.first!
        switch touch.tapCount {
        case 1:
            handleSingleTap(touch)
        case 2:
            handleDoubleTap(touch)
            
        default:
            break;
        }
        nextResponder()
    }
    
    func handleDoubleTap(touch: UITouch) {
        delegate?.handleDoubleTap(self, touch: touch)
    }
    func handleSingleTap(touch: UITouch) {
        delegate?.handleSingleTap(self, touch: touch)
    }
}

//
//  UIView+Radius.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/5/25.
//  Copyright © 2016年 Riven. All rights reserved.
//

extension UIView {
    func addCornerRadiusAnimation(from: CGFloat, to: CGFloat, duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "cornerRadius")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        self.layer.addAnimation(animation, forKey: "cornerRadius")
        self.layer.cornerRadius = to
    }
}

//
//  UIImage+Rotation.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/5/25.
//  Copyright © 2016年 Riven. All rights reserved.
//

extension UIImage {
    func rotateImageByOrientation() -> UIImage {
        // No-op if the orientation is already correct
        guard self.imageOrientation != .Up
            else {
            return self
        }
        // we need to calculate the proper transformation to make the image upright.
        // we do it in 2 steps: Rotate if Left/ Right/Down, and then flip if Mirrored
        var transform = CGAffineTransformIdentity
        switch self.imageOrientation {
        case .Down, .DownMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, self.size.height)
            transform = CGAffineTransformRotate(transform, CGFloat(M_PI))
            
        case .Left, .LeftMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, 0)
            transform = CGAffineTransformRotate(transform, CGFloat(-M_PI_2))
            
        case .Right, .RightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, self.size.height)
            transform = CGAffineTransformRotate(transform, CGFloat(-M_PI_2))
        default:
            break;
        }
        
        switch self.imageOrientation {
        case .UpMirrored, .DownMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, 0)
            transform = CGAffineTransformScale(transform, -1, 1)
        case .LeftMirrored, .RightMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.height, 0)
            transform = CGAffineTransformScale(transform, -1, 1)
        default:
            break;
        }
        
        // Now we draw the underlying CGImage into a new context, applying the transform calculated above
        let ctx = CGBitmapContextCreate(nil, Int(self.size.width), Int(self.size.height), CGImageGetBitsPerComponent(self.CGImage), 0, CGImageGetColorSpace(self.CGImage), CGImageGetBitmapInfo(self.CGImage).rawValue)
        CGContextConcatCTM(ctx, transform)
        
        switch self.imageOrientation {
        case .Left, .LeftMirrored, .RightMirrored, .Right:
            CGContextDrawImage(ctx, CGRect(x: 0, y: 0, width: size.height, height: size.height), self.CGImage)
        default:
            CGContextDrawImage(ctx, CGRect(x: 0, y: 0, width: size.height, height: size.height), self.CGImage)
        }
        
        // And now we just create a new UIImage from the drawing context
        if let cgImage = CGBitmapContextCreateImage(ctx) {
            return UIImage(CGImage: cgImage)
        }
        
        return self
    }
}

//
//  SKLocalPhoto.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/5/25.
//  Copyright © 2016年 Riven. All rights reserved.
//

public class SKLocalPhoto: NSObject, SKPhotoProtocol {
    public var underlyingImage: UIImage!
    public var photoURL: String!
    public var shouldCachePhotoURLImage: Bool = false
    public var caption: String!
    public var index: Int = 0
    
    override init() {
        super.init()
    }
    
    convenience init(url: String) {
        self.init()
        photoURL = url
    }
    convenience init(url: String, holder: UIImage?) {
        self.init()
        photoURL = url
        underlyingImage = holder
    }
    
    public func checkCache() { }
    
    public func loadUnderlyingImageAndNotify() {
        if underlyingImage != nil && photoURL == nil {
            loadUnderlyingImageComplete()
        }
        
        if photoURL != nil {
            // Fetch image
            if NSFileManager.defaultManager().fileExistsAtPath(photoURL) {
                if let data = NSFileManager.defaultManager().contentsAtPath(photoURL) {
                    self.loadUnderlyingImageComplete()
                    if let image = UIImage(data: data) {
                        self.underlyingImage = image
                        self.loadUnderlyingImageComplete()
                    }
                }
            }
        }
    }
    
    public func loadUnderlyingImageComplete() {
        NSNotificationCenter.defaultCenter().postNotificationName("photoLoadingDidEndNotification", object: self)
    }
    
    // MARK: - Class func
    public class func photoWithImageURL(url: String) -> SKLocalPhoto {
        return SKLocalPhoto(url: url)
    }
    public class func photoWithImageURL(url: String, holder: UIImage?) -> SKLocalPhoto {
        return SKLocalPhoto(url: url, holder: holder)
    }
}

//
//  SKPhoto.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/5/25.
//  Copyright © 2016年 Riven. All rights reserved.
//

@objc public protocol SKPhotoProtocol: NSObjectProtocol {
    var underlyingImage: UIImage! { get }
    var caption: String! { get }
    var index: Int { get set }
    func loadUnderlyingImageAndNotify()
    func checkCache()
}

// MARK: - SKPhoto
public class SKPhoto: NSObject, SKPhotoProtocol {
    public var underlyingImage: UIImage!
    public var photoURL: String!
    public var shouldCachePhotoURLImage: Bool = false
    public var caption: String!
    public var index: Int = 0
    
    override init() {
        super.init()
    }
    
    convenience init(image: UIImage) {
        self.init()
        underlyingImage = image
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
    
    public func checkCache() {
        if photoURL != nil && shouldCachePhotoURLImage {
            if let img = UIImage.sharedSKPhotoCache().objectForKey(photoURL) as? UIImage {
                underlyingImage = img
            }
        }
    }
    
    public func loadUnderlyingImageAndNotify() {
        if underlyingImage != nil && photoURL == nil {
            loadUnderlyingImageComplete()
        }
        if photoURL != nil {
            // Fetch image
            let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
            if let nsURL = NSURL(string: photoURL) {
                session.dataTaskWithURL(nsURL, completionHandler: { [weak self] (response: NSData?, data: NSURLResponse?, error: NSError?) in
                    if let _self = self {
                        if error != nil {
                            dispatch_async(dispatch_get_main_queue()) {
                                _self.loadUnderlyingImageComplete()
                            }
                        }
                        if let res = response, let image = UIImage(data: res) {
                            if _self.shouldCachePhotoURLImage {
                                UIImage.sharedSKPhotoCache().setObject(image, forKey: _self.photoURL)
                            }
                            dispatch_async(dispatch_get_main_queue()) {
                                _self.underlyingImage = image
                                _self.loadUnderlyingImageComplete()
                            }
                        }
                        session.finishTasksAndInvalidate()
                    }
                    }).resume()
            }
        }
    }
    
    public func loadUnderlyingImageComplete() {
        NSNotificationCenter.defaultCenter().postNotificationName("photoLoadingDidEndNotification", object: self)
    }
    
    // MARK: - Class func
    public class func photoWithImage(image: UIImage) -> SKPhoto {
        return SKPhoto(image: image)
    }
    
    public class func photoWithImageURL(url: String) -> SKPhoto {
        return SKPhoto(url: url)
    }
    
    public class func photoWithImageURL(url: String, holder: UIImage?) -> SKPhoto {
        return SKPhoto(url: url, holder: holder)
    }
}

// MARK: - Extension UIImage
public extension UIImage {
    private class func sharedSKPhotoCache() -> NSCache! {
        struct StaticSharedSKPhotoCache {
            static var sharedCache: NSCache? = nil
            static var onceToken: dispatch_once_t = 0
        }
        dispatch_once(&StaticSharedSKPhotoCache.onceToken) {
            StaticSharedSKPhotoCache.sharedCache = NSCache()
        }
        return StaticSharedSKPhotoCache.sharedCache!
    }
}

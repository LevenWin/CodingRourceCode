//
//  ImageTransition.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
public enum ImageTransition {
    case none
    
    case fade(TimeInterval)
    
    case flipFromLeft(TimeInterval)
    
    case flipFromRight(TimeInterval)
    
    case flipFromBottom(TimeInterval)
    
    case flipFromTop(TimeInterval)
    
    case custom(duration: TimeInterval, options: UIView.AnimationOptions, animations: ((UIImageView, UIImage) -> Void)?)
    
}
#endif

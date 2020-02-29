//
//  Placeholder.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

public protocol Placeholder {
    func add(to imageView: ImageView)
    
    func remove(from imageView: ImageView)
}

extension Image: Placeholder {
    public func add(to imageView: ImageView) {
        imageView.image = self
    }
    public func remove(from imageView: ImageView) {
        imageView.image = nil
    }
}
extension Placeholder where Self: View {
    public func add(to imageView: ImageView) {
        imageView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        
        centerXAnchor.constraint(equalTo: imageView.centerXAnchor).isActive = true
        centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
        heightAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        widthAnchor.constraint(equalTo: imageView.widthAnchor).isActive = true
    }
    
    public func remove(from imageView: ImageView) {
        removeFromSuperview()
    }
}

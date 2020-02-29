//
//  ImageDataProcessor.swift
//  KingFisher
//
//  Created by leven on 2020/2/28.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
private let sharedProcessQueue: CallbackQueue = .dispatch(DispatchQueue(label: "com.onvcat.Kingfisher.ImageDownloader.Process"))
class ImageDataProcessor {
    let data: Data
    let callbacks: [SessionDataTask.TaskCallback]
    let queue: CallbackQueue
    
    let onImageProcessed = Delegate<(Result<Image, KingfisherError>, SessionDataTask.TaskCallback), Void>()
    
    init(data: Data, callbacks: [SessionDataTask.TaskCallback], processingQueue: CallbackQueue?) {
        self.data = data
        self.callbacks = callbacks
        self.queue = processingQueue ?? sharedProcessQueue
    }
    func process() {
        queue.execute(doProcess)
    }
    
    func doProcess() {
        var processedImages = [String: Image]()
        
        for callback in callbacks {
            let processor = callback.options.processor
            var image = processedImages[processor.identifier]
            if image == nil {
                image = processor.process(item: .data(data), options: callback.options)
                processedImages[processor.identifier] = image
            }
            let result: Result<Image, KingfisherError>
            if let image = image {
                var finalImage = image
                if let imageModifier = callback.options.imageModifier {
//                    finalImage = imageModifier.mod
                }
                if callback.options.backgroundDecode {
//                    finalImage = finalImage.kf.
                }
                result = .success(finalImage)
            } else {
                let error = KingfisherError.processError(reason: .processingFailed(processor: processor, item: .data(data)))
                result = .failure(error)
            }
            onImageProcessed.call((result, callback))
        }
    }
}

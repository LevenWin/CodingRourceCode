//
//  Delegate.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

class Delegate<Input, Output> {
    init() {
        
    }
    
    private var block: ((Input) -> Output?)?
    
    func delegate<T: AnyObject>(on target: T, block: ((T, Input) -> Output)?) {
        self.block = { [weak target] input in
            guard let target = target else { return nil }
            return block?(target, input)
        }
    }
    func call(_ input: Input) -> Output? {
        return block?(input)
    }
}

extension Delegate where Input == Void {
    func call() -> Output? {
        return call(())
    }
}

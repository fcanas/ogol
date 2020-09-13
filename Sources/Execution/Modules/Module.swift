//
//  Module.swift
//  OgoLang
//
//  Created by Fabian Canas on 6/2/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public protocol Module {
    var procedures: [String : Procedure] { get }
    func initialize(context: ExecutionContext)
}

extension Module {
    public func initialize(context: ExecutionContext) {}
}


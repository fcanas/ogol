//
//  Module.swift
//  LogoLang
//
//  Created by Fabian Canas on 6/2/20.
//

public protocol Module {
    var procedures: [String : Procedure] { get }
    func initialize(context: ExecutionContext)
}

extension Module {
    public func initialize(context: ExecutionContext) {}
}


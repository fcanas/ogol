//
//  Module.swift
//  LogoLang
//
//  Created by Fabian Canas on 6/2/20.
//

public protocol Module {
    static var procedures: [String : NativeProcedure] { get }
    static func initialize(context: ExecutionContext)
}

extension Module {
    public static func initialize(context: ExecutionContext) {}
}

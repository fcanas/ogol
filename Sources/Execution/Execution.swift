//
//  Execution.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/2/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public enum ExecutionHandoff: Error {
    case stop
    case error(Runtime, String) // TODO: node that can be tied back to source?
    case output(Bottom)
    
    public enum Runtime {
        case typeError
        case missingSymbol
        case parameter
        case maxDepth
        case corruptAST
        case noOutput
        case module
    }
}

public struct Program: Codable {
    
    public var description: String = "Program" // TODO

    public var commands: [ExecutionNode]

    public var procedures: [String : Procedure]

    public init(executionNodes: [ExecutionNode], procedures:[Procedure]) {
        var p: [String : Procedure] = [:]
        procedures.forEach { (procedure) in
            p[procedure.name] = procedure
        }
        self.commands = executionNodes
        self.procedures = p
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let context: ExecutionContext = reuseScope ? context : try ExecutionContext(parent: context, procedures: procedures)
        for command in commands {
            try command.execute(context: context, reuseScope: false)
        }
    }
}




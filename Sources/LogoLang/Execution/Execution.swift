//
//  Execution.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/2/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

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

public protocol ExecutionNode: CustomStringConvertible {
    func execute(context: ExecutionContext, reuseScope: Bool) throws
}

public struct Program {
    
    public var description: String = "Program" // TODO

    public var commands: [ExecutionNode]

    public var procedures: [String : Procedure]

    init(executionNodes: [ExecutionNode]) {
        var c: [ExecutionNode] = []
        var p: [String : Procedure] = [:]
        executionNodes.forEach { (node) in
            if let procedure = node as? Procedure {
                p[procedure.name] = procedure
            } else {
                c.append(node)
            }
        }
        self.commands = c
        self.procedures = p
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let context: ExecutionContext = reuseScope ? context : try ExecutionContext(parent: context, procedures: procedures)
        for command in commands {
            try command.execute(context: context, reuseScope: false)
        }
    }
}

public protocol Procedure: ExecutionNode {
    var name: String { get }
    var parameters: [String] { get }
    var procedures: [String : Procedure] { get }
}

public class ConcreteProcedure: Procedure, CustomStringConvertible{

    public var name: String
    public var commands: [ExecutionNode]
    public var procedures: [String : Procedure]
    /// Ordered, named parameters for the procedure.
    public var parameters: [String]

    init(name: String, commands: [ExecutionNode], procedures: [String: Procedure], parameters: [Value]) {
        self.name = name
        self.commands = commands
        self.procedures = procedures
        self.parameters = parameters.map({ guard case let .deref(s) = $0 else {fatalError()}; return s })
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let ctx: ExecutionContext = reuseScope ? context : try ExecutionContext(parent: context, procedures: procedures)
        
        var idx = 0
        while idx < commands.count {
            let command = commands[idx]
            do {
                if idx == commands.count - 1, let invocation = command as? ProcedureInvocation, invocation.name == self.name {
                    let (_, parameterMap) = try invocation.evaluateParameters(in: ctx)
                    parameterMap.forEach { (key: String, value: Bottom) in
                        ctx.variables[key] = value
                    }
                    idx = 0
                    continue
                }
                try command.execute(context: ctx, reuseScope: false)
            } catch ExecutionHandoff.stop {
                return
            }
            idx += 1
        }
    }

    public var description: String {
        return "to \(name) " + parameters.map( { ":\($0) "
        } ).joined(separator: " ") + commands.reduce("") { (result, command) -> String in
            result + command.description
        }
    }
}

struct Block: ExecutionNode {
    var description: String { get { "[]-> " + commands.description } }

    var commands: [ExecutionNode]

    var procedures: [String : Procedure]
    
    func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let context: ExecutionContext = reuseScope ? context : try ExecutionContext(parent: context, procedures: procedures)
        for command in commands {
            try command.execute(context: context, reuseScope: false) // todo, last command in block?
        }
    }
}

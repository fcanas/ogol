//
//  Execution.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/2/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

// MARK: Scope

public protocol Scope: ExecutionNode {

    var commands: [ExecutionNode] { get }

    var procedures: [String: Procedure] { get }

}

struct CommandList: ExecutionNode {
    var description: String { get { commands.description } }
    
    func execute(context: ExecutionContext, reuseScope: Bool) throws {
        for command in commands {
            try command.execute(context: context, reuseScope: false) // TODO: look
        }
    }
    let commands: [ExecutionNode]
}

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

public struct Program: Scope {
    
    public var description: String = "Program" // TODO

    public var commands: [ExecutionNode]

    public var procedures: [String : Procedure]

    init(executionNodes: [ExecutionNode]) {
        var c: [ExecutionNode] = []
        var p: [String : Procedure] = [:]
        executionNodes.forEach { (node) in
            if let commands = node as? CommandList {
                c.append(contentsOf: commands.commands)
            } else if let procedure = node as? Procedure {
                p[procedure.name] = procedure
            } else {
                c.append(node)
            }
        }
        self.commands = c
        self.procedures = p
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let context: ExecutionContext = try ExecutionContext(parent: context, procedures: procedures)
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

public class ConcreteProcedure: Procedure, Scope, CustomStringConvertible{

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
        for (idx, command) in commands.enumerated() {
            do {
                try command.execute(context: ctx, reuseScope: idx == (commands.count - 1))
            } catch ExecutionHandoff.stop {
                return
            }
        }
    }

    public var description: String {
        return "to \(name) " + parameters.map( { ":\($0) "
        } ).joined(separator: " ") + commands.reduce("") { (result, command) -> String in
            result + command.description
        }
    }
}

public struct ProcedureInvocation: ExecutionNode, Equatable {

    let name: String
    let parameters: [Value]
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        
        guard let procedure = context.procedures[name] else {
            throw ExecutionHandoff.error(.missingSymbol, "I don't know how to \(name)")
        }
        
        guard procedure.parameters.count == parameters.count else {
            throw ExecutionHandoff.error(.parameter, "\(name) needs \(procedure.parameters.count) parameters. I found \(parameters.count).")
        }
        
        var parameterMap: Dictionary<String,Bottom> = Dictionary(minimumCapacity: parameters.count)
        for (index, parameter) in parameters.enumerated() {
            parameterMap[procedure.parameters[index]] = try parameter.evaluate(context: context)
        }
        
        let newScope: ExecutionContext
        if reuseScope {
            context.inject(procedures: procedure.procedures)
            parameterMap.forEach { (key: String, value: Bottom) in
                context.variables[key] = value
            }
            newScope = context
        } else {
            newScope = try ExecutionContext(parent: context, procedures: procedure.procedures, variables: parameterMap)
        }
        
        try procedure.execute(context: newScope, reuseScope: false)
        
    }
}

extension ProcedureInvocation: Evaluatable {
    public var description: String {
        return "p:->" + name
    }

    public func evaluate(context: ExecutionContext) throws -> Bottom {
        do {
            try execute(context: context, reuseScope: false)
        } catch let ExecutionHandoff.output(bottom) {
            return bottom
        }
        throw ExecutionHandoff.error(.noOutput, "No value returned from \(self).")
    }
}

extension ProcedureInvocation: SyntaxColorable {
    public func syntaxCategory() -> SyntaxCategory? {
        return .procedureInvocation
    }
}

struct Block: ExecutionNode, Scope {
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

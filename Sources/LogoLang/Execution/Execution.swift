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

    var commands: [Command] { get }

    var procedures: [String: Procedure] { get }

}

struct CommandList: ExecutionNode {
    func execute(context: inout ExecutionContext?) throws {
        for command in commands {
            try command.execute(context: &context)
        }
    }
    let commands: [Command]
}

public extension Scope {

    func execute(context: inout ExecutionContext?) throws {
        var context: ExecutionContext? = try ExecutionContext(parent: context, procedures: procedures)
        for command in commands {
            try command.execute(context: &context)
        }
    }

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

public protocol ExecutionNode {
    func execute(context: inout ExecutionContext?) throws
}

public struct Program: Scope {

    public var commands: [Command]

    public var procedures: [String : Procedure]

    init(executionNodes: [ExecutionNode]) {
        var c: [Command] = []
        var p: [String : Procedure] = [:]
        executionNodes.forEach { (node) in
            if let commands = node as? CommandList {
                c.append(contentsOf: commands.commands)
            } else if let command = node as? Command {
                c.append(command)
            } else if let procedure = node as? Procedure {
                p[procedure.name] = procedure
            }
        }
        self.commands = c
        self.procedures = p
    }
}

public class Procedure: ExecutionNode, Scope, CustomStringConvertible{

    var name: String
    public var commands: [Command]
    public var procedures: [String : Procedure]
    /// Defined parameters for the procedure.
    /// Must be Value.deref
    var parameters: [Value]

    init(name: String, commands: [Command], procedures: [String: Procedure], parameters: [Value]) {
        self.name = name
        self.commands = commands
        self.procedures = procedures
        self.parameters = parameters
    }
    
    public func execute(context: inout ExecutionContext?) throws {
        var context: ExecutionContext? = try ExecutionContext(parent: context, procedures: procedures)
        for command in commands {
            do {
                try command.execute(context: &context)
            } catch ExecutionHandoff.stop {
                return
            }
        }
    }

    public var description: String {
        return "to \(name) " + parameters.map( {
            guard case let .deref(s) = $0 else {fatalError()}
            return ":\(s) "
        } ).joined(separator: " ") + commands.reduce("") { (result, command) -> String in
            result + command.description
        }
    }
}

public struct ProcedureInvocation: ExecutionNode, Command, Equatable {

    let name: String
    let parameters: [Value]
    
    // TODO: Output?
    public func execute(context: inout ExecutionContext?) throws {

            guard let procedure = context?.procedures[name] else {
                throw ExecutionHandoff.error(.missingSymbol, "I don't know how to \(name)")
            }
            guard procedure.parameters.count == parameters.count else {
                throw ExecutionHandoff.error(.parameter, "\(name) needs \(procedure.parameters.count) parameters. I found \(parameters.count).")
            }
            let parameterValues = try parameters.map { (e) -> Bottom in
                try e.evaluate(context: &context)
            }
            let parameterNames = try procedure.parameters.map { (parameterValue) -> String in
                switch parameterValue {
                case let .deref(parameterName):
                    return parameterName
                default:
                    assert(false, "This shouldn't have been parsed, but was for some reason")
                }
                throw ExecutionHandoff.error(.corruptAST, "Please file a bug: procedure believes its parameter value is \(parameterValue)")
            }
            let parameters = Dictionary(zip(parameterNames, parameterValues)) { (k1, k2) in
                return k2
            }
            var newScope: ExecutionContext? = try ExecutionContext(parent: context, procedures: procedure.procedures, variables: parameters)
            try procedure.execute(context: &newScope)

    }
}

extension ProcedureInvocation: Evaluatable {
    public var description: String {
        return "p:->" + name
    }

    public func evaluate(context: inout ExecutionContext?) throws -> Bottom {
        do {
            try execute(context: &context)
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

    var commands: [Command]

    var procedures: [String : Procedure]

}

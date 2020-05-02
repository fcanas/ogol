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

extension Array where Element == ExecutionNode {

}

struct CommandList: ExecutionNode {
    func execute(context: inout ExecutionContext?) -> Double? {
        commands.reduce(0) { (_, c) -> Double? in
            c.execute(context: &context)
        }
    }
    let commands: [Command]
}

struct NOP: Command {
    func execute(context: inout ExecutionContext?) -> Double? { nil }
}

public extension Scope {

    func execute(context: inout ExecutionContext?) -> Double? {
        var context: ExecutionContext? = ExecutionContext(parent: context, procedures: procedures)

        commands.forEach { (command) in
            _ = command.execute(context: &context)
        }
        return nil
    }

}

public protocol ExecutionNode {
    func execute(context: inout ExecutionContext?) -> Double?
}

public protocol TurtleCommandSource {
    var issueCommand: (Turtle.Command) -> Void { get set }
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

public class Procedure: ExecutionNode, Scope {

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

}

struct ProcedureInvocation: ExecutionNode, Command, Equatable {
    let name: String
    let parameters: [Expression]
    func execute(context: inout ExecutionContext?) -> Double? {
        guard let procedure = context?.procedures[name] else {
            // TODO: Runtime error
            return nil
        }
        guard procedure.parameters.count == parameters.count else {
            // TODO: Runtime error : expectd number of parameters
            return nil
        }
        let parameterValues = parameters.map { (e) -> Double in
            // TODO: Runtime error :
            e.execute(context: &context)!
        }
        let parameterNames = procedure.parameters.map { (parameterValue) -> String in
            switch parameterValue {
            case let .deref(parameterName):
                return parameterName
            default:
                assert(false, "This shouldn't have been parsed, but was for some reason")
            }
        }
        let parameters = Dictionary(zip(parameterNames, parameterValues)) { (k1, k2) in
            return k2
        }
        var newScope: ExecutionContext? = ExecutionContext(parent: context, procedures: procedure.procedures, variables: parameters)
        return procedure.execute(context: &newScope)
    }
}

extension ProcedureInvocation: SyntaxColorable {
    func syntaxCategory() -> SyntaxCategory? {
        return .procedureInvocation
    }
}

struct Block: ExecutionNode, Scope {

    var commands: [Command]

    var procedures: [String : Procedure]

}

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
    }
}

public protocol ExecutionNode {
    func execute(context: inout ExecutionContext?) throws
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

public class NativeProcedure: Procedure {

    public override var description: String {
        return "Native Procedure \(parameters)"
    }

    let action: ([Bottom], ExecutionContext) -> Bottom?
    
    public init(name: String, parameters: [Value], action: @escaping ([Bottom], ExecutionContext) -> Bottom?) {
        self.action = action
        super.init(name: name, commands: [], procedures: [:], parameters: parameters)
    }
    
    public override func execute(context: inout ExecutionContext?) throws {
        let p = try parameters.map { (deref) -> Bottom in
            guard case let .deref(s) = deref  else {
                throw ExecutionHandoff.error(.typeError, "Parameters should be derefs")
            }
            guard let v = context?.variables[s] else {
                throw ExecutionHandoff.error(.missingSymbol, "\(s) parameter required")
            }
            return v
        }
        if let output = action(p, context!) {
            throw ExecutionHandoff.output(output)
        }
    }
}

public struct ProcedureInvocation: ExecutionNode, Command, Equatable {

    enum Identifier: Equatable {
        case turtle(TurtleCommand.Partial)
        case user(String)
    }

    let identifier: Identifier
    let parameters: [Value]
    
    // TODO: Output?
    public func execute(context: inout ExecutionContext?) throws {

        switch identifier {
        case let .turtle(partial):
            guard partial.parameterCount == parameters.count else {
                // TODO: Runtime error
                return
            }
            let turtleCommand: TurtleCommand

            switch partial {
            case .fd:
                turtleCommand = .fd(parameters.first!.expressionValue())
            case .bk:
                turtleCommand = .bk(parameters.first!.expressionValue())
            case .rt:
                turtleCommand = .rt(parameters.first!.expressionValue())
            case .lt:
                turtleCommand = .lt(parameters.first!.expressionValue())
            case .cs:
                turtleCommand = .cs
            case .pu:
                turtleCommand = .pu
            case .pd:
                turtleCommand = .pd
            case .st:
                turtleCommand = .st
            case .ht:
                turtleCommand = .ht
            case .home:
                turtleCommand = .home
            case .setxy:
                turtleCommand = .setXY(parameters[0].expressionValue(), parameters[1].expressionValue())
            }
            return try turtleCommand.execute(context: &context)
        case let .user(name):
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
}

extension ProcedureInvocation: Evaluatable {
    public var description: String {
        switch self.identifier {

        case let .turtle(t):
            return t.rawValue
        case let .user(u):
            return u
        }
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
        switch identifier {
        case .turtle(_):
            return .builtin
        case .user(_):
            return .procedureInvocation
        }
    }
}

struct Block: ExecutionNode, Scope {

    var commands: [Command]

    var procedures: [String : Procedure]

}

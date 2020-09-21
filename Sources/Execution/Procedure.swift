//
//  Procedure.swift
//  OgoLang.Execution
//
//  Created by Fabian Canas on 6/6/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public protocol GenericProcedure: CustomStringConvertible {
    var name: String { get }
    var parameters: [String] { get }
    var procedures: [String : Procedure] { get }
    var hasRest: Bool { get }
    func execute(context: ExecutionContext, reuseScope: Bool) throws
}

extension GenericProcedure {
    static func approxEqual(_ lhs: GenericProcedure, _ rhs: GenericProcedure) -> Bool {
        return lhs.name == rhs.name &&
            lhs.parameters == rhs.parameters &&
            lhs.hasRest == rhs.hasRest
    }
}

public enum Procedure: GenericProcedure {
    
    public var description: String {
        return _procedure.description
    }
    
    private var _procedure: GenericProcedure {
        switch self {
        case let .extern(p):
            return p
        case let .native(p):
            return p
        }
    }
    
    public var name: String { self._procedure.name }
    public var parameters: [String] { self._procedure.parameters }
    public var procedures: [String : Procedure] { self._procedure.procedures }
    public var hasRest: Bool { self._procedure.hasRest }
    
    public func invocationValidWith(parameterCount: Int) -> Bool {
        if !hasRest {
            return parameterCount == parameters.count
        }
        return parameterCount >= (parameters.count - 1)
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        try _procedure.execute(context: context, reuseScope: reuseScope)
    }
    
    case native(NativeProcedure)
    case extern(GenericProcedure)
    
}

extension Procedure: Equatable {
    public static func == (lhs: Procedure, rhs: Procedure) -> Bool {
        switch (lhs, rhs) {
        case let (.extern(l), .extern(r)):
            return approxEqual(l, r)
        case let (.native(l), .native(r)):
            return l == r
        case (_, _):
            return false
        }
    }
}

extension Procedure: Codable {
    
    enum Key: CodingKey {
        case native
        case extern
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)

        if let native = try container.decodeIfPresent(NativeProcedure.self, forKey: .native) {
            self = .native(native)
            return
        } else if let extern = try container.decodeIfPresent(StandinProcedure.self, forKey: .extern) {
            self = .extern(extern)
            return
        }
        
        throw LogoCodingError.procedure
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .native(native):
            try container.encode(native, forKey: .native)
        case let .extern(extern):
            let standIn = StandinProcedure(name: extern.name, parameters: extern.parameters, procedures: [:], hasRest: extern.hasRest)
            try container.encode(standIn, forKey: .extern)
        }
    }
    
}

public struct StandinProcedure: GenericProcedure, Codable {
    public var name: String
    
    public var parameters: [String]
    
    public var procedures: [String : Procedure]
    
    public var hasRest: Bool
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        throw ExecutionHandoff.error(ExecutionHandoff.Runtime.missingSymbol, "An external procedure \(name) is missing")
    }
    
    public var description: String {
        "tbd:extern: \(name) :\(parameters.joined(separator: ", :"))"
    }
    
}

public final class NativeProcedure: GenericProcedure {

    public var name: String
    public var commands: [ProcedureInvocation]
    public var procedures: [String : Procedure]
    /// Ordered, named parameters for the procedure.
    public var parameters: [String]
    /// If true, this procedire can be invoked with an arbitrary number of parameters ` >= parameters.count`.
    /// If the number of parameters at invocation exceeds the number of declared parameters, the final
    /// parameter will be a list with the remaining values.
    ///
    /// Setting `hasRest` to `true` wihout zero values in `parameters` may lead to unexpected behavior.
    public var hasRest: Bool

    public init(name: String, commands: [ProcedureInvocation], procedures: [String: Procedure], parameters: [Value], hasRest: Bool = false) {
        self.name = name
        self.commands = commands
        self.procedures = procedures
        self.parameters = parameters.map({ guard case let .deref(s) = $0 else {fatalError()}; return s })
        self.hasRest = hasRest
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let ctx: ExecutionContext = reuseScope ? context : try ExecutionContext(parent: context, procedures: procedures)
        
        var idx = 0
        while idx < commands.count {
            let command = commands[idx]
            do {
                if idx == commands.count - 1, command.name == self.name {
                    let (_, parameterMap) = try command.evaluateParameters(in: ctx)
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

    
}

extension NativeProcedure: Equatable {
    public static func == (lhs: NativeProcedure, rhs: NativeProcedure) -> Bool {
        return lhs.name == rhs.name &&
            lhs.commands == rhs.commands &&
            lhs.procedures == rhs.procedures &&
            lhs.parameters == rhs.parameters &&
            lhs.hasRest == rhs.hasRest
    }
}

extension NativeProcedure: Codable {}

extension NativeProcedure: CustomStringConvertible {
    public var description: String {
        return "to \(name) " + parameters.map( { ":\($0) "
        } ).joined(separator: " ") + commands.reduce("") { (result, command) -> String in
            result + command.description
        }
    }
}


public class ExternalProcedure: GenericProcedure {

    public var name: String
    public var parameters: [String]
    public var procedures: [String : Procedure]
    public var hasRest: Bool
    
    public var description: String {
        return "Native Procedure \(parameters)"
    }

    let action: ([Bottom], ExecutionContext) throws -> Bottom?
    
    public init(name: String, parameters: [String], action: @escaping ([Bottom], ExecutionContext) throws -> Bottom?, hasRest: Bool = false) {
        self.name = name
        self.parameters = parameters
        self.action = action
        self.procedures = [:]
        self.hasRest = hasRest
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let p = try parameters.map { (parameterName) -> Bottom in
            guard let v = context.variables[parameterName] else {
                throw ExecutionHandoff.error(.missingSymbol, "\(parameterName) parameter required")
            }
            return v
        }
        if let output = try action(p, context) {
            throw ExecutionHandoff.output(output)
        }
    }
}

extension ExternalProcedure: Equatable {
    public static func == (lhs: ExternalProcedure, rhs: ExternalProcedure) -> Bool {
        return lhs.name == rhs.name &&
            lhs.parameters == rhs.parameters &&
            lhs.procedures == rhs.procedures &&
            lhs.hasRest == rhs.hasRest
    }
}

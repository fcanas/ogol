//
//  Procedure.swift
//  LogoLang
//
//  Created by Fabian Canas on 6/6/20.
//

import Foundation

public protocol GenericProcedure: CustomStringConvertible {
    var name: String { get }
    var parameters: [String] { get }
    var procedures: [String : Procedure] { get }
    func execute(context: ExecutionContext, reuseScope: Bool) throws
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
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        try _procedure.execute(context: context, reuseScope: reuseScope)
    }
    
    case native(NativeProcedure)
    case extern(GenericProcedure)
    
}

extension Procedure: Codable {
    
    enum Key: CodingKey {
        case type
        case value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(String.self, forKey: .type)
        switch rawValue {
        case "native":
            let nativeProcedure = try container.decode(NativeProcedure.self, forKey: .value)
            self = .native(nativeProcedure)
        case "extern":
            let standin = try container.decode(StandinProcedure.self, forKey: .value)
            self = .extern(standin)
        default:
            throw LogoCodingError.procedure
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .native(native):
            try container.encode("native", forKey: .type)
            try container.encode(native, forKey: .value)
        case let .extern(extern):
            try container.encode("extern", forKey: .type)
            let standIn = StandinProcedure(name: extern.name, parameters: extern.parameters, procedures: [:])
            try container.encode(standIn, forKey: .value)
        }
    }
    
}

public struct StandinProcedure: GenericProcedure, Codable {
    public var name: String
    
    public var parameters: [String]
    
    public var procedures: [String : Procedure]
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        throw ExecutionHandoff.error(ExecutionHandoff.Runtime.missingSymbol, "An external procedure \(name) is missing")
    }
    
    public var description: String {
        "tbd:extern: \(name) :\(parameters.joined(separator: ", :"))"
    }
    
    
}

public class NativeProcedure: GenericProcedure, CustomStringConvertible, Codable {

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
                if idx == commands.count - 1, case let .invocation(invocation) = command, invocation.name == self.name {
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

public class ExternalProcedure: GenericProcedure {

    public var name: String
    public var parameters: [String]
    public var procedures: [String : Procedure]
    
    public var description: String {
        return "Native Procedure \(parameters)"
    }

    let action: ([Bottom], ExecutionContext) throws -> Bottom?
    
    public init(name: String, parameters: [String], action: @escaping ([Bottom], ExecutionContext) throws -> Bottom?) {
        self.name = name
        self.parameters = parameters
        self.action = action
        self.procedures = [:]
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

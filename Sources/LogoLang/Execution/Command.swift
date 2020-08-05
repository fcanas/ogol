//
//  Command.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

public enum ExecutionNode: CustomStringConvertible, Equatable {
    
    public var description: String { "{{ Execution Node }}" }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        switch self {
        case let .list(block):
            try block.execute(context: context, reuseScope: reuseScope)
        case let .conditional(exec):
            try exec.execute(context: context, reuseScope: reuseScope)
        case let .invocation(exec):
            try exec.execute(context: context, reuseScope: reuseScope)
        }
    }
    
    case list(CommandList)
    case conditional(Conditional)
    case invocation(ProcedureInvocation)
}

extension ExecutionNode: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        
        if let list = try container.decodeIfPresent(CommandList.self, forKey: .list) {
            self = .list(list)
            return
        } else if let conditional = try container.decodeIfPresent(Conditional.self, forKey: .conditional) {
            self = .conditional(conditional)
            return
        } else if let inv = try container.decodeIfPresent(ProcedureInvocation.self, forKey: .invocation) {
            self = .invocation(inv)
            return
        }
        throw LogoCodingError.ExecutionNode
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .conditional(conditional):
            try container.encode(conditional, forKey: .conditional)
        case let .invocation(invocation):
            try container.encode(invocation, forKey: .invocation)
        case let .list(list):
            try container.encode(list, forKey: .list)
        }
    }
    
    enum Key: CodingKey {
        case list
        case rep
        case conditional
        case invocation
    }
    
}

public struct CommandList: Codable, Equatable {
    public var description: String { get { "[]-> " + commands.description } }

    var commands: [ExecutionNode]

    var procedures: [String : Procedure]
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let context: ExecutionContext = reuseScope ? context : try ExecutionContext(parent: context, procedures: procedures)
        for command in commands {
            try command.execute(context: context, reuseScope: false) // todo, last command in block?
        }
    }
}

public struct Conditional: Codable, Equatable {

    public var description: String {
        return "\(condition) [ \(block) ]"
    }

    var condition: Expression
    var block: CommandList

    init(condition: Expression, block: CommandList) {
        self.condition = condition
        self.block = block
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        guard case let .boolean(conditionValue) = try condition.evaluate(context: context) else {
                throw ExecutionHandoff.error(.typeError, "Conditional require a logical condition")
        }
        if conditionValue {
            try block.execute(context: context, reuseScope: reuseScope)
        }
    }

}

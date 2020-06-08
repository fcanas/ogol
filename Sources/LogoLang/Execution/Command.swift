//
//  Command.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

public enum ExecutionNode: CustomStringConvertible, _Executable {
    
    public var description: String { "{{ Execution Node }}" }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        switch self {
        case let .block(block):
            try block.execute(context: context, reuseScope: reuseScope)
        case let .stop(stop):
            try stop.execute(context: context, reuseScope: reuseScope)
        case let .rep(exec):
            try exec.execute(context: context, reuseScope: reuseScope)
        case let .make(exec):
            try exec.execute(context: context, reuseScope: reuseScope)
        case let .output(exec):
            try exec.execute(context: context, reuseScope: reuseScope)
        case let .conditional(exec):
            try exec.execute(context: context, reuseScope: reuseScope)
        case let .foreach(exec):
            try exec.execute(context: context, reuseScope: reuseScope)
        case let .invocation(exec):
            try exec.execute(context: context, reuseScope: reuseScope)
        }
    }
    
    case block(Block)
    case stop(Stop)
    case rep(Repeat)
    case make(Make)
    case output(Output)
    case conditional(Conditional)
    case foreach(For)
    case invocation(ProcedureInvocation)
}

extension ExecutionNode: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        switch rawValue {
        case "block":
            let value = try container.decode(Block.self, forKey: .associatedValue)
            self = .block(value)
        case "stop":
            let value = try container.decode(Stop.self, forKey: .associatedValue)
            self = .stop(value)
        case "rep":
            let value = try container.decode(Repeat.self, forKey: .associatedValue)
            self = .rep(value)
        case "make":
            let value = try container.decode(Make.self, forKey: .associatedValue)
            self = .make(value)
        case "output":
            let value = try container.decode(Output.self, forKey: .associatedValue)
            self = .output(value)
        case "conditional":
            let value = try container.decode(Conditional.self, forKey: .associatedValue)
            self = .conditional(value)
        case "foreach":
            let value = try container.decode(For.self, forKey: .associatedValue)
            self = .foreach(value)
        case "invocation":
            let value = try container.decode(ProcedureInvocation.self, forKey: .associatedValue)
            self = .invocation(value)
        default:
            throw LogoCodingError.ExecutionNode
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .block(block):
            try container.encode("block", forKey: .rawValue)
            try container.encode(block, forKey: .associatedValue)
        case let .stop(stop):
            try container.encode("stop", forKey: .rawValue)
            try container.encode(stop, forKey: .associatedValue)
        case let .rep(rep):
            try container.encode("rep", forKey: .rawValue)
            try container.encode(rep, forKey: .associatedValue)
        case let .make(make):
            try container.encode("make", forKey: .rawValue)
            try container.encode(make, forKey: .associatedValue)
        case let .output(output):
            try container.encode("output", forKey: .rawValue)
            try container.encode(output, forKey: .associatedValue)
        case let .conditional(conditional):
            try container.encode("conditional", forKey: .rawValue)
            try container.encode(conditional, forKey: .associatedValue)
        case let .foreach(foreach):
            try container.encode("foreach", forKey: .rawValue)
            try container.encode(foreach, forKey: .associatedValue)
        case let .invocation(invocation):
            try container.encode("invocation", forKey: .rawValue)
            try container.encode(invocation, forKey: .associatedValue)
        }
    }
    
    enum Key: CodingKey {
        case rawValue
        case associatedValue
    }
    
}

public struct Block: _Executable, Codable {
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

public struct Stop: _Executable, Codable {
    public var description: String {
        return "stop"
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        throw ExecutionHandoff.stop
    }
}

public struct Repeat: _Executable, Codable {
    public var description: String {
        return "repeat " + count.description + " " + block.description
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        var executed = 0
        guard case let .double(limit) = try count.evaluate(context: context) else {
            throw ExecutionHandoff.error(.typeError, "Tried to use non-numeric repeat value")
        }
        while executed < Int(limit) {
            try block.execute(context: context, reuseScope: reuseScope)
            executed += 1
        }
    }

    init(count: SignExpression, block: Block) {
        self.count = count
        self.block = block
    }

    var count: SignExpression
    var block: Block

}

public struct Make: _Executable, Codable {

    public var description: String {
        return "make \"\(symbol) \(value)"
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        context.variables[symbol] = try value.evaluate(context: context)
    }

    var value: Value
    var symbol: String
}

public struct Output: _Executable, Codable {
    public var description: String {
        return "output \(value)"
    }
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        throw ExecutionHandoff.output(try value.evaluate(context: context))
    }
    var value: Value
}

public struct Conditional: _Executable, Codable {

    public var description: String {
        return "\(lhs) \(comparisonOp) \(rhs) [ \(block) ]"
    }

    enum Comparison: String, CustomStringConvertible, Codable {
        var description: String {
            switch self {
            case .lt:
                return "<"
            case .gt:
                return ">"
            case .eq:
                return "="
            }
        }
        case lt
        case gt
        case eq
    }

    let comparisonOp: Comparison
    let lhs: Expression
    let rhs: Expression
    let block: Block

    init(lhs: Expression, comparison: Comparison, rhs: Expression, block: Block) {
        self.lhs = lhs
        self.comparisonOp = comparison
        self.rhs = rhs
        self.block = block
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        guard case let .double(lhsv) = try lhs.evaluate(context: context),
            case let .double(rhsv) = try rhs.evaluate(context: context) else {
                throw ExecutionHandoff.error(.typeError, "Conditional statements can only compare numbers")
        }
        switch self.comparisonOp {
        case .lt:
            if lhsv < rhsv {
                try block.execute(context: context, reuseScope: reuseScope)
            }
        case .gt:
            if lhsv > rhsv {
                try block.execute(context: context, reuseScope: reuseScope)
            }
        case .eq:
            if lhsv == rhsv {
                try block.execute(context: context, reuseScope: reuseScope)
            }
        }
    }

}

public struct For: _Executable, Codable {

    public var description: String {
        return "for"
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        // TODO
        fatalError()
        // inherit reuse scope
    }

    init(block: Block) {
        self.block = block
    }

    let block: Block
}

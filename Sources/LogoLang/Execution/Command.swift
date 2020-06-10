//
//  Command.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

public enum ExecutionNode: CustomStringConvertible {
    
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
        
        if let block = try container.decodeIfPresent(Block.self, forKey: .block) {
            self = .block(block)
            return
        } else if let stop = try container.decodeIfPresent(Stop.self, forKey: .stop) {
            self = .stop(stop)
            return
        } else if let rep = try container.decodeIfPresent(Repeat.self, forKey: .rep) {
            self = .rep(rep)
            return
        } else if let make = try container.decodeIfPresent(Make.self, forKey: .make) {
            self = .make(make)
            return
        } else if let output = try container.decodeIfPresent(Output.self, forKey: .output) {
            self = .output(output)
            return
        } else if let conditional = try container.decodeIfPresent(Conditional.self, forKey: .conditional) {
            self = .conditional(conditional)
            return
        } else if let fore = try container.decodeIfPresent(For.self, forKey: .foreach) {
            self = .foreach(fore)
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
        case let .block(block):
            try container.encode(block, forKey: .block)
        case let .stop(stop):
            try container.encode(stop, forKey: .stop)
        case let .rep(rep):
            try container.encode(rep, forKey: .rep)
        case let .make(make):
            try container.encode(make, forKey: .make)
        case let .output(output):
            try container.encode(output, forKey: .output)
        case let .conditional(conditional):
            try container.encode(conditional, forKey: .conditional)
        case let .foreach(foreach):
            try container.encode(foreach, forKey: .foreach)
        case let .invocation(invocation):
            try container.encode(invocation, forKey: .invocation)
        }
    }
    
    enum Key: CodingKey {
        case block
        case stop
        case rep
        case make
        case output
        case conditional
        case foreach
        case invocation
    }
    
}

public struct Block: Codable {
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

public struct Stop: Codable {
    public var description: String {
        return "stop"
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        throw ExecutionHandoff.stop
    }
}

public struct Repeat: Codable {
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

public struct Make: Codable {

    public var description: String {
        return "make \"\(symbol) \(value)"
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        context.variables[symbol] = try value.evaluate(context: context)
    }

    var value: Value
    var symbol: String
}

public struct Output: Codable {
    public var description: String {
        return "output \(value)"
    }
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        throw ExecutionHandoff.output(try value.evaluate(context: context))
    }
    var value: Value
}

public struct Conditional: Codable {

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
    var lhs: Expression
    var rhs: Expression
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

public struct For: Codable {

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

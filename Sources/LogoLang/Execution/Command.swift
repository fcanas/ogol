//
//  Command.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation


public protocol Command: ExecutionNode, CustomStringConvertible { }

struct Stop: Command {
    var description: String {
        return "stop"
    }

    func execute(context: inout ExecutionContext?) throws {
        throw ExecutionHandoff.stop
    }
}

struct Repeat: Command {
    var description: String {
        return "repeat " + count.description + " " + "[ TODO : Block Description]"
    }

    func execute(context: inout ExecutionContext?) throws {
        var executed = 0
        guard case let .double(limit) = try count.evaluate(context: &context) else {
            throw ExecutionHandoff.error(.typeError, "Tried to use non-numeric repeat value")
        }
        while executed < Int(limit) {
            try block.execute(context: &context)
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

struct Make: Command {

    var description: String {
        return "make \"\(symbol) \(value)"
    }

    func execute(context: inout ExecutionContext?) throws {
        assert(context != nil)
        context!.variables[symbol] = try value.evaluate(context: &context)
    }

    var value: Evaluatable
    var symbol: String
}

struct Output: Command {
    var description: String {
        return "output \(value)"
    }
    func execute(context: inout ExecutionContext?) throws {
        throw ExecutionHandoff.output(try value.evaluate(context: &context))
    }
    var value: Evaluatable
}

struct Conditional: Command {

    var description: String {
        return "\(lhs) \(comparisonOp) \(rhs) [ TODO : Block ]"
    }

    enum Comparison: CustomStringConvertible {
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

    func execute(context: inout ExecutionContext?) throws {
        // TODO : raise errors
        guard case let .double(lhsv) = try lhs.evaluate(context: &context),
            case let .double(rhsv) = try rhs.evaluate(context: &context) else {
                throw ExecutionHandoff.error(.typeError, "Conditional statements can only compare numbers")
        }
        switch self.comparisonOp {
        case .lt:
            if lhsv < rhsv {
                try block.execute(context: &context)
            }
        case .gt:
            if lhsv > rhsv {
                try block.execute(context: &context)
            }
        case .eq:
            if lhsv == rhsv {
                try block.execute(context: &context)
            }
        }
    }

}

struct For: Command {

    var description: String {
        return "for"
    }

    func execute(context: inout ExecutionContext?) {
        // TODO
        fatalError()
    }

    init(block: Block) {
        self.block = block
    }

    let block: Block
}

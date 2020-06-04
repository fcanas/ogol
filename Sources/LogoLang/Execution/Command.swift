//
//  Command.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

struct Stop: ExecutionNode {
    var description: String {
        return "stop"
    }

    func execute(context: ExecutionContext, reuseScope: Bool) throws {
        throw ExecutionHandoff.stop
    }
}

struct Repeat: ExecutionNode {
    var description: String {
        return "repeat " + count.description + " " + "[ TODO : Block Description]"
    }

    func execute(context: ExecutionContext, reuseScope: Bool) throws {
        var executed = 0
        guard case let .double(limit) = try count.evaluate(context: context) else {
            throw ExecutionHandoff.error(.typeError, "Tried to use non-numeric repeat value")
        }
        while executed < Int(limit) {
            try block.execute(context: context, reuseScope: false) // TODO: consider tail recursion in repeat node
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

struct Make: ExecutionNode {

    var description: String {
        return "make \"\(symbol) \(value)"
    }

    func execute(context: ExecutionContext, reuseScope: Bool) throws {
        context.variables[symbol] = try value.evaluate(context: context)
    }

    var value: Evaluatable
    var symbol: String
}

struct Output: ExecutionNode {
    var description: String {
        return "output \(value)"
    }
    func execute(context: ExecutionContext, reuseScope: Bool) throws {
        throw ExecutionHandoff.output(try value.evaluate(context: context))
    }
    var value: Evaluatable
}

struct Conditional: ExecutionNode {

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

    func execute(context: ExecutionContext, reuseScope: Bool) throws {
        // TODO : raise errors
        guard case let .double(lhsv) = try lhs.evaluate(context: context),
            case let .double(rhsv) = try rhs.evaluate(context: context) else {
                throw ExecutionHandoff.error(.typeError, "Conditional statements can only compare numbers")
        }
        switch self.comparisonOp {
        case .lt:
            if lhsv < rhsv {
                try block.execute(context: context, reuseScope: false)
            }
        case .gt:
            if lhsv > rhsv {
                try block.execute(context: context, reuseScope: false)
            }
        case .eq:
            if lhsv == rhsv {
                try block.execute(context: context, reuseScope: false)
            }
        }
    }

}

struct For: ExecutionNode {

    var description: String {
        return "for"
    }

    func execute(context: ExecutionContext, reuseScope: Bool) {
        // TODO
        fatalError()
    }

    init(block: Block) {
        self.block = block
    }

    let block: Block
}

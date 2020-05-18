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

enum TurtleCommand: Command, Equatable {

    var description: String {
        switch self {
        case let .fd(v): return "fd \(v)"
        case let .bk(v): return "bk \(v)"
        case let .rt(v): return "rt \(v)"
        case let .lt(v): return "lt \(v)"
        case .cs: return "cs"
        case .pu: return "pu"
        case .pd: return "pd"
        case .st: return "st"
        case .ht: return "ht"
        case .home: return "home"
        case let .setXY(x, y): return "setxy \(x) \(y)"
        }
    }

    enum Partial: String, RawRepresentable, CaseIterable {
        case fd
        case bk
        case rt
        case lt
        case cs
        case pu
        case pd
        case st
        case ht
        case home
        case setxy

        var parameterCount: Int {
            switch self {
            case .fd, .bk, .rt, .lt:
                return 1
            case .cs, .pu, .pd, .st, .ht, .home:
                return 0
            case .setxy:
                return 2
            }
        }
    }

    case fd(Expression)
    case bk(Expression)
    case rt(Expression)
    case lt(Expression)
    case cs
    case pu
    case pd
    case st
    case ht
    case home
    case setXY(Expression, Expression)

    func execute(context: inout ExecutionContext?) throws {
        switch self {
        case let .fd(e):
            guard case let .double(value) = try e.evaluate(context: &context) else {
                throw ExecutionHandoff.error(.typeError, "I can only go forward by a number")
            }
            context?.issueCommand(Turtle.Command.fd(value))
        case let .bk(e):
            guard case let .double(value) = try e.evaluate(context: &context) else {
                throw ExecutionHandoff.error(.typeError, "I can only go back by a number")
            }
            context?.issueCommand(Turtle.Command.bk(value))
        case let .rt(e):
            guard case let .double(value) = try e.evaluate(context: &context) else {
                throw ExecutionHandoff.error(.typeError, "I can only go right by a number")
            }
            context?.issueCommand(Turtle.Command.rt(value))
        case let .lt(e):
            guard case let .double(value) = try e.evaluate(context: &context) else {
                throw ExecutionHandoff.error(.typeError, "I can only go left by a number")
            }
            context?.issueCommand(Turtle.Command.lt(value))
        case .cs:
            fatalError()
        // context?.issueCommand(Turtle.Command.cs)
        case .pu:
            context?.issueCommand(Turtle.Command.pu)
        case .pd:
            context?.issueCommand(Turtle.Command.pd)
        case .st:
            context?.issueCommand(Turtle.Command.st)
        case .ht:
            context?.issueCommand(Turtle.Command.ht)
        case .home:
            context?.issueCommand(Turtle.Command.home)
        case let .setXY(xExpression, yExpression):
            guard case let .double(x) = try xExpression.evaluate(context: &context),
                case let .double(y) = try yExpression.evaluate(context: &context) else {
                    throw ExecutionHandoff.error(.typeError, "setxy needs the horizontal and vertical positions to be numbers")
            }
            context?.issueCommand(Turtle.Command.setxy(Point(x: x, y: y)))
        }
    }
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

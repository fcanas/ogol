//
//  Command.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation


public protocol Command: ExecutionNode { }

struct Stop: Command {
    func execute(context: inout ExecutionContext?) throws {
        throw ExecutionHandoff.stop
    }
}

struct Repeat: Command {

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
    func execute(context: inout ExecutionContext?) throws {
        assert(context != nil)
        context!.variables[symbol] = try value.evaluate(context: &context)
    }

    var value: Value
    var symbol: String
}

enum TurtleCommand: Command, Equatable {

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

    enum Comparison {
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

    func execute(context: inout ExecutionContext?) {
        // TODO
        fatalError()
    }

    init(block: Block) {
        self.block = block
    }

    let block: Block
}

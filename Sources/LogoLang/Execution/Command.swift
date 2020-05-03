//
//  Command.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation


public protocol Command: ExecutionNode { }

struct Repeat: Command {

    func execute(context: inout ExecutionContext?) -> Double? {
        var executed = 0
        let limit = count.execute(context: &context)!
        while executed < Int(limit) {
            _ = block.execute(context: &context)
            executed += 1
        }
        return nil
    }

    init(count: SignExpression, block: Block) {
        self.count = count
        self.block = block
    }

    var count: SignExpression
    var block: Block

}

struct Make: Command {
    func execute(context: inout ExecutionContext?) -> Double? {
        assert(context != nil)
        context!.variables[symbol] = value.execute(context: &context)
        return nil
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
        case setXY

        var parameterCount: Int {
            switch self {
            case .fd, .bk, .rt, .lt:
                return 1
            case .cs, .pu, .pd, .st, .ht, .home:
                return 0
            case .setXY:
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
    case setXY(SignExpression, SignExpression)

    func execute(context: inout ExecutionContext?) -> Double? {
        switch self {
        case let .fd(e):
            let value = e.execute(context: &context)!
            context?.issueCommand(Turtle.Command.fd(Double(value)))
        case let .bk(e):
            let value = e.execute(context: &context)!
            context?.issueCommand(Turtle.Command.bk(Double(value)))
        case let .rt(e):
            let value = e.execute(context: &context)!
            context?.issueCommand(Turtle.Command.rt(Double(value)))
        case let .lt(e):
            let value = e.execute(context: &context)!
            context?.issueCommand(Turtle.Command.lt(Double(value)))
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
            let x = xExpression.execute(context: &context)!
            let y = yExpression.execute(context: &context)!
            context?.issueCommand(Turtle.Command.setxy(Point(x: x, y: y)))
        }
        return nil
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

    func execute(context: inout ExecutionContext?) -> Double? {
        // TODO : raise errors
        let lhsv = lhs.execute(context: &context)!
        let rhsv = rhs.execute(context: &context)!
        switch self.comparisonOp {
        case .lt:
            if lhsv < rhsv {
                _ = block.execute(context: &context)
            }
        case .gt:
            if lhsv > rhsv {
                _ = block.execute(context: &context)
            }
        case .eq:
            if lhsv == rhsv {
                _ = block.execute(context: &context)
            }
        }
        return nil
    }

}

struct For: Command {

    func execute(context: inout ExecutionContext?) -> Double? {
        // TODO
        fatalError()
    }

    init(block: Block) {
        self.block = block
    }

    let block: Block
}

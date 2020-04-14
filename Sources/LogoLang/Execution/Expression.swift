//
//  Expression.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

struct SignExpression: ExecutionNode, Equatable {
    enum Sign {
        case positive
        case negative
    }
    var sign: Sign?
    var value: Value
    init(sign: Sign, value: Value) {
        self.sign = sign
        self.value = value
    }
    
    func execute(context: inout ExecutionContext?) -> Double? {
        let multiplier: Double
        switch sign {
        case .negative:
            multiplier = -1.0
        default:
            multiplier = 1.0
        }
        return multiplier * self.value.execute(context: &context)!
    }
}

struct MultiplyingExpression: Equatable {

    init(lhs: SignExpression, rhs: MultiplyingExpression.Rhs) {
        self.lhs = lhs
        self.rhs = [rhs]
    }

    init(lhs: SignExpression, rhs: [MultiplyingExpression.Rhs] = []) {
        self.lhs = lhs
        self.rhs = rhs
    }

    struct Rhs: Equatable {
        var operation: MultiplyingOperation
        var rhs: SignExpression
    }

    enum MultiplyingOperation {
        case multiply
        case divide
    }

    var lhs: SignExpression
    var rhs: [Rhs]

    func execute(context: inout ExecutionContext?) -> Double? {

        // TODO : LHS shouldn't be nil
        let lhsv = self.lhs.execute(context: &context)!

        return rhs.reduce(lhsv) { (result, rhs) -> Double in
            switch rhs.operation {
            case .multiply:
                return result * rhs.rhs.execute(context: &context)!
            case .divide:
                return result / rhs.rhs.execute(context: &context)!
            }
        }
    }
}

struct Expression: ExecutionNode, Equatable {

    internal init(lhs: MultiplyingExpression, rhs: Expression.Rhs) {
        self.lhs = lhs
        self.rhs = [rhs]
    }

    internal init(lhs: MultiplyingExpression, rhs: [Expression.Rhs] = []) {
        self.lhs = lhs
        self.rhs = rhs
    }

    struct Rhs: Equatable {
        var operation: ExpressionOperation
        var rhs: MultiplyingExpression
    }

    enum ExpressionOperation: Equatable {
        case add
        case subtract
    }

    var lhs: MultiplyingExpression
    var rhs: [Rhs]

    func execute(context: inout ExecutionContext?) -> Double? {

        // TODO : LHS shouldn't be nil
        let lhsv = self.lhs.execute(context: &context)!

        return rhs.reduce(lhsv) { (result, rhs) -> Double in
            switch rhs.operation {
            case .add:
                return result + rhs.rhs.execute(context: &context)!
            case .subtract:
                return result - rhs.rhs.execute(context: &context)!
            }
        }

    }
}

enum Value: ExecutionNode, Equatable {
    func execute(context: inout ExecutionContext?) -> Double? {
        switch self {
        case let .expression(e):
            return e.execute(context: &context)
        case let .deref(symbol):
            // TODO: raise errors instead of silently failing
            return context?.variables[symbol] ?? 0.0
        case let .number(n):
            return n
        }
    }

    indirect case expression(Expression)
    case deref(String)
    // handles some expression cases nicely to keep this here.
    // TODO: revisit.
    case number(Double)
}

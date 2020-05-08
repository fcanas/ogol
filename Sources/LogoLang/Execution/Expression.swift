//
//  Expression.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

public enum Bottom {
    case double(Double)
}

protocol Evaluatable {
    func evaluate(context: inout ExecutionContext?) -> Bottom
}

struct SignExpression: Evaluatable, Equatable {
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
    
    func evaluate(context: inout ExecutionContext?) -> Bottom {
        let multiplier: Double
        switch sign {
        case .negative:
            multiplier = -1.0
        default:
            multiplier = 1.0
        }
        
        guard case let .double(value) = self.value.evaluate(context: &context) else {
            // TODO: Runtime error
            fatalError()
        }
        
        return .double(multiplier * value)
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

    func evaluate(context: inout ExecutionContext?) -> Bottom {

        // TODO : LHS shouldn't be nil
        
        guard case let .double(lhsv) = self.lhs.evaluate(context: &context) else {
            fatalError()
        }

        return .double(rhs.reduce(lhsv) { (result, rhs) -> Double in
            guard case let .double(rhsv) = rhs.rhs.evaluate(context: &context) else {
                // TODO: Runtime error
                fatalError()
            }
            switch rhs.operation {
            case .multiply:
                return result * rhsv
            case .divide:
                return result / rhsv
            }
        })
    }
}

struct Expression: Evaluatable, Equatable {

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

    func evaluate(context: inout ExecutionContext?) -> Bottom {
        
        guard case let .double(lhsv) = self.lhs.evaluate(context: &context) else {
            // TODO: Runtime error
            fatalError()
        }

        return .double(rhs.reduce(lhsv) { (result, rhs) -> Double in
            guard case let .double(rhsv) = rhs.rhs.evaluate(context: &context) else {
                // TODO: Runtime Error
                fatalError()
            }
            switch rhs.operation {
            case .add:
                return result + rhsv
            case .subtract:
                return result - rhsv
            }
        })

    }
}

enum Value: Evaluatable, Equatable {
    func evaluate(context: inout ExecutionContext?) -> Bottom {
        switch self {
        case let .expression(e):
            return e.evaluate(context: &context)
        case let .deref(symbol):
            // TODO: raise errors instead of silently failing
            return context?.variables[symbol] ?? .double(0)
        case let .number(n):
            return .double(n)
        }
    }

    indirect case expression(Expression)
    case deref(String)
    // handles some expression cases nicely to keep this here.
    // TODO: revisit.
    case number(Double)
}

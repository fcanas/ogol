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
    case string(String)
}

protocol Evaluatable {
    func evaluate(context: inout ExecutionContext?)throws -> Bottom
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
    
    func evaluate(context: inout ExecutionContext?) throws -> Bottom {
        let multiplier: Double
        switch sign {
        case .negative:
            multiplier = -1.0
        default:
            multiplier = 1.0
        }
        
        guard case let .double(value) = try self.value.evaluate(context: &context) else {
            throw ExecutionHandoff.error(.typeError, "I can only negate a number")
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

    func evaluate(context: inout ExecutionContext?) throws -> Bottom {

        // TODO : LHS shouldn't be nil
        
        guard case let .double(lhsv) = try self.lhs.evaluate(context: &context) else {
            throw ExecutionHandoff.error(.typeError, "Multiplying expressions should be between two numbers")
        }

        return try .double(rhs.reduce(lhsv) { (result, rhs) -> Double in
            guard case let .double(rhsv) = try rhs.rhs.evaluate(context: &context) else {
                throw ExecutionHandoff.error(.typeError, "Multiplying expressions should be between two numbers")
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

public struct Expression: Evaluatable, Equatable {

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

    func evaluate(context: inout ExecutionContext?) throws -> Bottom {
        
        guard case let .double(lhsv) = try self.lhs.evaluate(context: &context) else {
            throw ExecutionHandoff.error(.typeError, "Only numbers can be added and subtracted")
        }

        return try .double(rhs.reduce(lhsv) { (result, rhs) -> Double in
            guard case let .double(rhsv) = try rhs.rhs.evaluate(context: &context) else {
                throw ExecutionHandoff.error(.typeError, "Only numbers can be added and subtracted")
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

public enum Value: Evaluatable, Equatable {
    func evaluate(context: inout ExecutionContext?) throws -> Bottom {
        switch self {
        case let .expression(e):
            return try e.evaluate(context: &context)
        case let .deref(symbol):
            guard let value = context?.variables[symbol] else {
                throw ExecutionHandoff.error(.missingSymbol, "Value not found for \(symbol)")
            }
            return value
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

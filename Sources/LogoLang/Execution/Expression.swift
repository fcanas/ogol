//
//  Expression.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation


public protocol Evaluatable: CustomStringConvertible {
    func evaluate(context: ExecutionContext) throws -> Bottom
}

enum SignExpression: Evaluatable, Equatable {

    case positive(Value)
    case negative(Value)
    
    var description: String {
        switch self {
        case let .negative(value):
            return "-\(value.description)"
        case let .positive(value):
            return value.description
        }
    }
    
    func evaluate(context: ExecutionContext) throws -> Bottom {
        switch self {
        case let .negative(value):
            let v = try value.evaluate(context: context)
            switch v {
            case var .double(doubleValue):
                doubleValue.negate()
                return .double(doubleValue)
            default:
                return v
            }
        case let .positive(value):
            return try value.evaluate(context: context)
        }
    }
}

struct MultiplyingExpression: Equatable, CustomStringConvertible {

    public var description: String {
        return "\(lhs)" + rhs.reduce("", { (sum, item) in return sum + item.description })
    }


    init(lhs: SignExpression, rhs: MultiplyingExpression.Rhs) {
        self.lhs = lhs
        self.rhs = [rhs]
    }

    init(lhs: SignExpression, rhs: [MultiplyingExpression.Rhs] = []) {
        self.lhs = lhs
        self.rhs = rhs
    }

    struct Rhs: Equatable, CustomStringConvertible {
        var description: String {
            return operation.description + " " + rhs.description
        }
        var operation: MultiplyingOperation
        var rhs: SignExpression
    }

    enum MultiplyingOperation {
        var description: String {
            switch self {
            case .multiply:
                return "*"
            case .divide:
                return "/"
            }
        }
        case multiply
        case divide
    }

    var lhs: SignExpression
    var rhs: [Rhs]

    func evaluate(context: ExecutionContext) throws -> Bottom {

        // Sort-circuit strings out
        if case let .string(s) = try self.lhs.evaluate(context: context) {
            return .string(s)
        }
        
        guard case let .double(lhsv) = try self.lhs.evaluate(context: context) else {
            throw ExecutionHandoff.error(.typeError, "Multiplying expressions should be between two numbers")
        }

        return try .double(rhs.reduce(lhsv) { (result, rhs) -> Double in
            guard case let .double(rhsv) = try rhs.rhs.evaluate(context: context) else {
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

    public var description: String {
        return "\(lhs)" + rhs.reduce("", { (sum, item) in return sum + item.description })
    }

    internal init(lhs: MultiplyingExpression, rhs: Expression.Rhs) {
        self.lhs = lhs
        self.rhs = [rhs]
    }

    internal init(lhs: MultiplyingExpression, rhs: [Expression.Rhs] = []) {
        self.lhs = lhs
        self.rhs = rhs
    }

    struct Rhs: Equatable, CustomStringConvertible {

        var description: String {
            return operation.description + " " + rhs.description
        }

        var operation: ExpressionOperation
        var rhs: MultiplyingExpression
    }

    enum ExpressionOperation: Equatable, CustomStringConvertible {
        var description: String {
            switch self {
            case .add:
                return "+"
            case .subtract:
                return "-"
            }
        }
        case add
        case subtract
    }

    var lhs: MultiplyingExpression
    var rhs: [Rhs]

    public func evaluate(context: ExecutionContext) throws -> Bottom {
        
        // Short-circuit strings
        if case let .string(s) = try self.lhs.evaluate(context: context) {
            return .string(s)
        }
        
        guard case let .double(lhsv) = try self.lhs.evaluate(context: context) else {
            throw ExecutionHandoff.error(.typeError, "Only numbers can be added and subtracted")
        }

        return try .double(rhs.reduce(lhsv) { (result, rhs) -> Double in
            guard case let .double(rhsv) = try rhs.rhs.evaluate(context: context) else {
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

    public var description: String {
        switch self {
        case let .deref(d):
            return ":\(d)"
        case let .expression(e):
            return e.description
        case let .number(n):
            return n.description
        case let .string(s):
            return s
        case let .procedure(p):
            return "{\(p)}"
        }
    }

    public func evaluate(context: ExecutionContext) throws -> Bottom {
        switch self {
        case let .expression(e):
            return try e.evaluate(context: context)
        case let .deref(symbol):
            guard let value = context.variables[symbol] else {
                throw ExecutionHandoff.error(.missingSymbol, "Value not found for \(symbol)")
            }
            return value
        case let .number(n):
            return .double(n)
        case let .string(s):
            return .string(s)
        case let .procedure(p):
            return try p.evaluate(context: context)
        }
    }
    
    func expressionValue() -> Expression {
        guard case let .expression(e) = self else {
            fatalError() // TODO: make things than need expressions take something else instead?
        }
        return e
    }

    indirect case expression(Expression)
    case deref(String)
    // handles some expression cases nicely to keep this here.
    // TODO: revisit.
    case number(Double)
    case string(String)
    case procedure(ProcedureInvocation)
}

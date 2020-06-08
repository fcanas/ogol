//
//  Expression.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

enum SignExpression: Equatable {
    
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

extension SignExpression: Codable {
    
    enum Key: CodingKey {
        case rawValue
        case associatedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        let value = try container.decode(Value.self, forKey: .associatedValue)
        switch rawValue {
        case "positive":
            self = .positive(value)
        case "negative":
            self = .negative(value)
        default:
            throw LogoCodingError.signExpression
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .positive(value):
            try container.encode("positive", forKey: .rawValue)
            try container.encode(value, forKey: .associatedValue)
        case let .negative(value):
            try container.encode("negative", forKey: .rawValue)
            try container.encode(value, forKey: .associatedValue)
        }
    }
    
    
}

struct MultiplyingExpression: Equatable, CustomStringConvertible, Codable {
    
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
    
    struct Rhs: Equatable, CustomStringConvertible, Codable {
        var description: String {
            return operation.rawValue + " " + rhs.description
        }
        var operation: MultiplyingOperation
        var rhs: SignExpression
    }
    
    enum MultiplyingOperation: String, Codable {
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

public struct Expression: Equatable, Codable {
    
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
    
    struct Rhs: Equatable, CustomStringConvertible, Codable {
        
        var description: String {
            return operation.rawValue + " " + rhs.description
        }
        
        var operation: ExpressionOperation
        var rhs: MultiplyingExpression
    }
    
    enum ExpressionOperation: String, Codable {
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

public enum Value: Equatable {
    
    public var description: String {
        switch self {
        case let .deref(d):
            return ":\(d)"
        case let .expression(e):
            return e.description
        case let .bottom(b):
            return b.description
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
        case let .bottom(bottom):
            return bottom
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
    case bottom(Bottom)
    case procedure(ProcedureInvocation)
}

extension Value: Codable {
    enum Key: CodingKey {
        case rawValue
        case associatedValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        switch rawValue {
        case "deref":
            let value = try container.decode(String.self, forKey: .associatedValue)
            self = .deref(value)
        case "expression":
            let value = try container.decode(Expression.self, forKey: .associatedValue)
            self = .expression(value)
        case "bottom":
            let value = try container.decode(Bottom.self, forKey: .associatedValue)
            self = .bottom(value)
        case "procedure":
            let value = try container.decode(ProcedureInvocation.self, forKey: .associatedValue)
            self = .procedure(value)
        default:
            throw LogoCodingError.signExpression
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        
        switch self {
        case let .deref(name):
            try container.encode("deref", forKey: .rawValue)
            try container.encode(name, forKey: .associatedValue)
        case let .expression(expression):
            try container.encode("expression", forKey: .rawValue)
            try container.encode(expression, forKey: .associatedValue)
        case let .bottom(bottom):
            try container.encode("bottom", forKey: .rawValue)
            try container.encode(bottom, forKey: .associatedValue)
        case let .procedure(proc):
            try container.encode("procedure", forKey: .rawValue)
            try container.encode(proc, forKey: .associatedValue)
        }
    }
}

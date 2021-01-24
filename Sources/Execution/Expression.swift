//
//  Expression.swift
//  OgoLang.Execution
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public enum SignExpression {
    
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
                // TODO: What to do about negating a string?
                return v
            }
        case let .positive(value):
            return try value.evaluate(context: context)
        }
    }
}

extension SignExpression: Codable, Equatable {
    
    enum Key: CodingKey {
        case positive
        case negative
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        if let value = try container.decodeIfPresent(Value.self, forKey: .positive) {
            self = .positive(value)
            return
        } else if let value = try container.decodeIfPresent(Value.self, forKey: .negative) {
            self = .negative(value)
            return
        }
        throw LogoCodingError.signExpression
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .positive(value):
            try container.encode(value, forKey: .positive)
        case let .negative(value):
            try container.encode(value, forKey: .negative)
        }
    }
}

public struct MultiplyingExpression: Equatable, CustomStringConvertible {
    
    public var description: String {
        return "\(lhs)" + rhs.reduce("", { (sum, item) in return sum + item.description })
    }
    
    public init(lhs: SignExpression, rhs: MultiplyingExpression.Rhs) {
        self.lhs = lhs
        self.rhs = [rhs]
    }
    
    public init(lhs: SignExpression, rhs: [MultiplyingExpression.Rhs] = []) {
        self.lhs = lhs
        self.rhs = rhs
    }
    
    public struct Rhs: Equatable, CustomStringConvertible {
        public init(operation: MultiplyingExpression.Operation, rhs: SignExpression) {
            self.operation = operation
            self.rhs = rhs
        }
        
        public var description: String {
            return operation.rawValue + " " + rhs.description
        }
        var operation: Operation
        var rhs: SignExpression
    }
    
    public enum Operation: String {
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
        
        let lhsv = try self.lhs.evaluate(context: context)
        
        switch lhsv {
        case let .double(lhsv):
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
        default:
            return lhsv
        }
        
    }
}

public struct ArithmeticExpression: Equatable {
    
    public var description: String {
        return "\(lhs)" + rhs.reduce("", { (sum, item) in return sum + item.description })
    }
    
    public init(lhs: MultiplyingExpression, rhs: ArithmeticExpression.Rhs) {
        self.lhs = lhs
        self.rhs = [rhs]
    }
    
    public init(lhs: MultiplyingExpression, rhs: [ArithmeticExpression.Rhs] = []) {
        self.lhs = lhs
        self.rhs = rhs
    }
    
    public struct Rhs: Equatable, CustomStringConvertible {
        public init(operation: ArithmeticExpression.Operation, rhs: MultiplyingExpression) {
            self.operation = operation
            self.rhs = rhs
        }
        
        public var description: String {
            return operation.rawValue + " " + rhs.description
        }
        
        var operation: Operation
        var rhs: MultiplyingExpression
    }
    
    public enum Operation: String {
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
        
        let lhsv = try self.lhs.evaluate(context: context)
        
        switch lhsv {
        case let .double(lhsv):
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
        default:
            return lhsv
        }
    }
}

public struct Expression: Equatable {
    
    public init(lhs: ArithmeticExpression, rhs: Expression.Rhs? = nil) {
        self.lhs = lhs
        self.rhs = rhs
    }
    
    var lhs: ArithmeticExpression
    var rhs: Rhs?
    
    public struct Rhs: Equatable {
        
        public init(operation: Expression.Operation, rhs: ArithmeticExpression) {
            self.operation = operation
            self.rhs = rhs
        }
        
        var description: String {
            return operation.rawValue + " " + rhs.description
        }
        var operation: Operation
        var rhs: ArithmeticExpression
    }
    
    public enum Operation: String, CustomStringConvertible {
        public var description: String {
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
    
    public var description: String {
        return "\(lhs)" + (rhs?.description ?? "")
    }
    
    public func evaluate(context: ExecutionContext) throws -> Bottom {
        
        let lhsv = try self.lhs.evaluate(context: context)
        
        guard let rhs = rhs else {
            return lhsv
        }
        
        let rhsv = try rhs.rhs.evaluate(context: context)
        
        switch (lhsv, rhsv) {
        case let (.double(lhsv), .double(rhsv)):
            switch rhs.operation {
            case .eq:
                return .boolean(lhsv == rhsv)
            case .lt:
                return .boolean(lhsv < rhsv)
            case .gt:
                return .boolean(lhsv > rhsv)
            }
        case (.list(_), .list(_)):
            throw ExecutionHandoff.error(.typeError, "lists are unsupported")
        case let (.boolean(lhsv), .boolean(rhsv)):
            switch rhs.operation {
            case .eq:
                return .boolean(lhsv == rhsv)
            default:
                throw ExecutionHandoff.error(.typeError, "Booleans can only be compared with `=`.")
            }
        default:
            // TODO: Does this belong here or elsewhere?
            //    guard op == .eq else {
            //        throw ExecutionHandoff.error(.typeError, "= comparison only possible with boolean types. Left hand side not boolean")
            //    }
            //    guard case let .boolean(rhsbv) = try self.rhs.evaluate(context: context) else {
            //        throw ExecutionHandoff.error(.typeError, "= comparison only possible with boolean types. Right hand side not boolean")
            //    }
            //    return .boolean(lhsbv == rhsbv)
            throw ExecutionHandoff.error(.typeError, "Comparisons are for numbers and booleans.")
        }
    }
    
}

// TODO: Does this language need logical expressions?
/*
public struct LogicalExpression: Equatable, Codable {
    
    var lhs: BooleanValue
    var rhs: [Rhs]
    
    public var description: String {
        return "\(lhs)" + rhs.reduce("", { (sum, item) in return sum + item.description })
    }
    
    enum BooleanValue: Codable, Equatable {
        
        case expression(ComparisonExpression)
        case bottom(Bottom)
        indirect case logical(LogicalExpression)
        
        enum Key: CodingKey {
            case expression
            case bottom
            case logical
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            if let expression = try container.decodeIfPresent(ComparisonExpression.self, forKey: .expression) {
                self = .expression(expression)
                return
            }
            if let bottom = try container.decodeIfPresent(Bottom.self, forKey: .bottom){
                self = .bottom(bottom)
                return
            }
            if let logical = try container.decodeIfPresent(LogicalExpression.self, forKey: .logical) {
                self = .logical(logical)
                return
            }
            throw LogoCodingError.logicalExpression
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)
            switch self {
            case let .bottom(b):
                try container.encode(b, forKey: .bottom)
            case let .expression(e):
                try container.encode(e, forKey: .expression)
            case let .logical(l):
                try container.encode(l, forKey: .expression)
            }
        }
    }
    
    struct Rhs: Equatable, CustomStringConvertible, Codable {
        
        var description: String {
            return operation.rawValue + " " + rhs.description
        }
        
        var operation: LogicalOperation
        var rhs: LogicalExpression
    }
    
    enum LogicalOperation: String, Codable {
        case and
        case or
    }
    
    public func evaluate(context: ExecutionContext) throws -> Bottom {
        return .boolean(true)
    }
}
 */

public enum Value: Equatable {
    
    indirect case expression(Expression)
    case reference(String)
    case deref(String)
    case bottom(Bottom)
    
    public var description: String {
        switch self {
        case let .reference(r):
            return ":\(r)"
        case let .deref(d):
            return "\(d)"
        case let .expression(e):
            return e.description
        case let .bottom(b):
            return b.description
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
            switch bottom {
            case let .command(invocation):
                return try invocation.evaluate(context: context)
            default:
                return bottom
            }
        case let .reference(key):
            let resolvedContext = context.variables.storeContaining(key: key)?.container
            return .reference(key, resolvedContext ?? context)
        }
    }
    
    func expressionValue() -> Expression {
        guard case let .expression(e) = self else {
            fatalError() // TODO: make things than need expressions take something else instead?
        }
        return e
    }
}

// MARK: - Codable

extension MultiplyingExpression: Codable {
    enum Key: CodingKey {
        case lhs
        case rhs
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.lhs = try container.decode(SignExpression.self, forKey: .lhs)
        self.rhs = try container.decodeIfPresent([Rhs].self, forKey: .rhs) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        
        try container.encode(self.lhs, forKey: .lhs)
        if rhs.count > 0 {
            try container.encode(self.rhs, forKey: .rhs)
        }
    }
}
extension MultiplyingExpression.Rhs: Codable { }
extension MultiplyingExpression.Operation: Codable { }
extension ArithmeticExpression: Codable {
    enum Key: CodingKey {
        case lhs
        case rhs
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.lhs = try container.decode(MultiplyingExpression.self, forKey: .lhs)
        self.rhs = try container.decodeIfPresent([Rhs].self, forKey: .rhs) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        
        try container.encode(self.lhs, forKey: .lhs)
        if rhs.count > 0 {
            try container.encode(self.rhs, forKey: .rhs)
        }
    }
}
extension ArithmeticExpression.Rhs: Codable { }
extension ArithmeticExpression.Operation: Codable { }
extension Expression: Codable { }
extension Expression.Rhs: Codable { }
extension Expression.Operation: Codable { }

extension Value: Codable {
    enum Key: CodingKey {
        case reference
        case expression
        case deref
        case bottom
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        if let expression = try container.decodeIfPresent(Expression.self, forKey: .expression) {
            self = .expression(expression)
            return
        } else if let deref = try container.decodeIfPresent(String.self, forKey: .deref) {
            self = .deref(deref)
            return
        } else if let bottom = try container.decodeIfPresent(Bottom.self, forKey: .bottom) {
            self = .bottom(bottom)
            return
        } else if let reference = try container.decodeIfPresent(String.self, forKey: .reference) {
            self = .reference(reference)
            return
        }
        throw LogoCodingError.signExpression
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        
        switch self {
        case let .deref(name):
            try container.encode(name, forKey: .deref)
        case let .expression(expression):
            try container.encode(expression, forKey: .expression)
        case let .bottom(bottom):
            try container.encode(bottom, forKey: .bottom)
        case let .reference(r):
            try container.encode(r, forKey: .reference)
        }
    }
}

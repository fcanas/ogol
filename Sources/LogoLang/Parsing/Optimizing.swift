//
//  Optimizing.swift
//  exLogo
//
//  Created by Fabian Canas on 6/9/20.
//

import Foundation

public enum Optimizer: Module {
    public static var procedures: [String : Procedure] = ["optimize":.extern(Optimizer.optimize)]
    
    static var optimize: ExternalProcedure = ExternalProcedure(name: "optimize", parameters: ["procedure"]) { (params, context) -> Bottom? in
        guard case let .string(name) = params.first else {
            throw ExecutionHandoff.error(ExecutionHandoff.Runtime.parameter, "Needs a single string parameter.")
        }
        guard var candidateProcedure = context.procedures[name] else {
            throw ExecutionHandoff.error(ExecutionHandoff.Runtime.missingSymbol, "Procedure \(name) not found to optimize")
        }
        guard case let .native(procedure) = candidateProcedure else {
            throw ExecutionHandoff.error(ExecutionHandoff.Runtime.parameter, "Unable to optimize external procedure. Expected a native procedure -- One written in Logo.")
        }
        
        procedure.reduceExpressions()
        
        return nil
    }
}

protocol ExpressionReducable {}

extension SignExpression: ExpressionReducable {
    /// Returns a value if the sign expression can be structurally elided
    ///
    /// Positive case is always a no-op, and so could be elided if the container can be.
    /// A Bottom.double can also be locally negated and elided.
    ///
    /// - Returns: A value equivalent to the sign expression
    func simplified() -> Value? {
        switch self {
        case let .positive(value):
            return value
        case let .negative(value):
            switch value {
            case let .bottom(bottom):
                return .bottom(bottom.negated())
            default:
                return nil
            }
        }
    }
}

extension Bottom {
    func negated() -> Bottom {
        switch self {
        case var .double(d):
            d.negate()
            return .double(d)
        case .string(_):
            return self
        case let .list(l):
            return .list(l.map({$0.negated()}))
        }
    }
}

extension MultiplyingExpression: ExpressionReducable {
    
    mutating func reduce() {
        var reduced: Double = 1
        var unreduced: [MultiplyingExpression.Rhs] = []
        rhs.forEach { (aRHS) in
            if let rhsValue = aRHS.rhs.simplified() {
                switch rhsValue {
                case let .bottom(bottom):
                    switch bottom {
                    case let .double(double):
                        switch aRHS.operation {
                        case .multiply:
                            reduced *= double
                        case .divide:
                            reduced /= double
                        }
                    default:
                        unreduced.append(aRHS)
                    }
                default:
                    unreduced.append(aRHS)
                }
            } else {
                unreduced.append(aRHS)
            }
        }
        if let simplifiedLHS = lhs.simplified(),
            case let .bottom(bottom) = simplifiedLHS,
            case let .double(double) = bottom
        {
            reduced *= double
        } else {
            unreduced.append(MultiplyingExpression.Rhs(operation: .multiply, rhs: lhs))
        }
        
        if unreduced.count <= rhs.count {
            lhs = SignExpression.positive(Value.bottom(.double(reduced)))
            rhs = unreduced
        }
    }
    
    mutating func simplified() -> Value? {
        reduce()
        if rhs.isEmpty {
            return lhs.simplified()
        }
        return nil
    }
}

extension Expression: ExpressionReducable {
    
    mutating func reduce() {
        var reduced: Double = 0
        var unreduced: [Expression.Rhs] = []
        rhs = rhs.map({ r in
            var rr = r
            rr.rhs.reduce()
            return rr
        })
        rhs.forEach { (axRHS) in
            var aRHS = axRHS
            aRHS.rhs.reduce()
            if let rhsValue = aRHS.rhs.simplified() {
                switch rhsValue {
                case let .bottom(bottom):
                    switch bottom {
                    case let .double(double):
                        switch aRHS.operation {
                        case .add:
                            reduced += double
                        case .subtract:
                            reduced -= double
                        }
                    default:
                        unreduced.append(aRHS)
                    }
                default:
                    unreduced.append(aRHS)
                }
            } else {
                unreduced.append(aRHS)
            }
        }
        lhs.reduce()
        if let simplifiedLHS = lhs.simplified(),
            case let .bottom(bottom) = simplifiedLHS,
            case let .double(double) = bottom
        {
            reduced += double
        } else {
            unreduced.append(Expression.Rhs(operation: .add, rhs: lhs))
        }
        
        if unreduced.count <= rhs.count {
            lhs = MultiplyingExpression(lhs: SignExpression.positive(Value.bottom(.double(reduced))))
            rhs = unreduced
        }
    }
    
    mutating func simplified() -> Value? {
        reduce()
        if rhs.isEmpty {
            return lhs.simplified()
        }
        return nil
    }
}

extension Value: ExpressionReducable {
    
    mutating func reduce() {
        simplify()
    }
    
    mutating func simplify() {
        switch self {
        case var .expression(expression):
            if let simplifiedValue = expression.simplified() {
                self = simplifiedValue
            } else {
                expression.reduce()
                self = .expression(expression)
            }
        default:
            return
        }
    }
}

extension Make {
    mutating func reduce() {
        value.reduce()
    }
}

extension Output {
    mutating func reduce() {
        value.reduce()
    }
}

extension Conditional {
    mutating func reduce() {
        lhs.reduce()
        rhs.reduce()
    }
}

extension ProcedureInvocation {
    mutating func reduce() {
        parameters = parameters.map { (value) -> Value in
            var v = value
            v.reduce()
            return v
        }
    }
}

extension Block {
    mutating func reduce() {
        commands = commands.map(reduceNodeExpressions)
    }
}

extension Repeat {
    mutating func reduce() {
        block.reduce()
    }
}

func reduceNodeExpressions(_ node: ExecutionNode) -> ExecutionNode {
    switch node {
    case var .block(block):
        block.reduce()
        return .block(block)
    case var .conditional(cond):
        cond.reduce()
        return .conditional(cond)
    case .foreach(_):
        break
    case var .invocation(inv):
        inv.reduce()
        return .invocation(inv)
    case var .make(make):
        make.reduce()
        return .make(make)
    case var .output(out):
        out.reduce()
        return .output(out)
    case var .rep(rep):
        rep.reduce()
        return .rep(rep)
    case .stop(_):
        break
    }
    return node
}

extension NativeProcedure {
    func reduceExpressions() {
        commands = commands.map(reduceNodeExpressions)
    }
}


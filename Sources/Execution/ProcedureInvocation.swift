//
//  ProcedureInvocation.swift
//  LogoLang
//
//  Created by Fabian Canas on 6/6/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public struct ProcedureInvocation: Equatable {

    public let name: String
    public var parameters: [Value]
    
    public func evaluateParameters(in context: ExecutionContext) throws -> (Procedure, Dictionary<String,Bottom>) {
        guard let procedure = context.procedures[name] else {
            throw ExecutionHandoff.error(.missingSymbol, "I don't know how to \(name)")
        }
        
        let minimumParameters = procedure.parameters.count - (procedure.hasRest ? 1 : 0)
        
        guard minimumParameters <= parameters.count else {
            throw ExecutionHandoff.error(.parameter, "\(name) needs \(minimumParameters)\(procedure.hasRest ? " or more":"") parameters. I found \(parameters.count).")
        }
        
        var parameterMap: Dictionary<String,Bottom> = Dictionary(minimumCapacity: procedure.parameters.count)
        
        if procedure.hasRest {
            var parameterNames = procedure.parameters
            guard let restName = parameterNames.popLast() else {
                throw ExecutionHandoff.error(.parameter, "Parameter count mismatch with Rest parameter")
            }
            
            for (index, parameterName) in parameterNames.enumerated() {
                parameterMap[parameterName] = try parameters[index].evaluate(context: context)
            }
            parameterMap[restName] = try .list(parameters[parameterNames.count..<parameters.count].map({
                try $0.evaluate(context: context)
            }))
        } else {
            for (index, parameter) in parameters.enumerated() {
                parameterMap[procedure.parameters[index]] = try parameter.evaluate(context: context)
            }
        }
        
        return (procedure, parameterMap)
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        
        let (procedure, parameterMap) = try evaluateParameters(in: context)
        
        let newScope: ExecutionContext
        if reuseScope {
            context.inject(procedures: procedure.procedures)
            parameterMap.forEach { (key: String, value: Bottom) in
                context.variables[key] = value
            }
            newScope = context
        } else {
            newScope = try ExecutionContext(parent: context, procedures: procedure.procedures, variables: parameterMap)
        }
        
        try procedure.execute(context: newScope, reuseScope: reuseScope)
        
    }
    
    public init(name: String, parameters: [Value]) {
        self.name = name
        self.parameters = parameters
    }
}

extension ProcedureInvocation { // Value
    public var description: String {
        return "p:->" + name
    }

    public func evaluate(context: ExecutionContext) throws -> Bottom {
        do {
            try execute(context: context, reuseScope: false)
        } catch let ExecutionHandoff.output(bottom) {
            return bottom
        }
        throw ExecutionHandoff.error(.noOutput, "No value returned from \(self).")
    }
}

extension ProcedureInvocation: Codable {
    
}

extension ExecutionNode {
    public func evaluate(context: ExecutionContext) throws -> Bottom {
        do {
            try execute(context: context, reuseScope: false)
        } catch let ExecutionHandoff.output(bottom) {
            return bottom
        }
        throw ExecutionHandoff.error(.noOutput, "No value returned from \(self).")
    }
}

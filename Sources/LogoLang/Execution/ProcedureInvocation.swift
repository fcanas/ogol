//
//  ProcedureInvocation.swift
//  LogoLang
//
//  Created by Fabian Canas on 6/6/20.
//

import Foundation

public struct ProcedureInvocation: Equatable {

    let name: String
    let parameters: [Value]
    
    public func evaluateParameters(in context: ExecutionContext) throws -> (Procedure, Dictionary<String,Bottom>) {
        guard let procedure = context.procedures[name] else {
            throw ExecutionHandoff.error(.missingSymbol, "I don't know how to \(name)")
        }
        
        guard procedure.parameters.count == parameters.count else {
            throw ExecutionHandoff.error(.parameter, "\(name) needs \(procedure.parameters.count) parameters. I found \(parameters.count).")
        }
        
        var parameterMap: Dictionary<String,Bottom> = Dictionary(minimumCapacity: parameters.count)
        for (index, parameter) in parameters.enumerated() {
            parameterMap[procedure.parameters[index]] = try parameter.evaluate(context: context)
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

extension ProcedureInvocation: SyntaxColorable {
    public func syntaxCategory() -> SyntaxCategory? {
        return .procedureInvocation
    }
}

extension ProcedureInvocation: Codable {
    
}

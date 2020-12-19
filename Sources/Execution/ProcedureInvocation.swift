//
//  ProcedureInvocation.swift
//  OgoLang.Execution
//
//  Created by Fabian Canas on 6/6/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public struct ProcedureInvocation: Equatable {

    public let name: String
    public var parameters: [Value]
    
    public func evaluateParameters(in context: ExecutionContext) throws -> (Procedure, [String : Bottom]) {
        guard let procedure = context.procedures[name] else {
            throw ExecutionHandoff.error(.missingSymbol, "I don't know how to \(name)")
        }
        
        guard procedure.invocationValidWith(parameterCount: parameters.count) else {
            let minimumParameters = procedure.parameters.count - (procedure.hasRest ? 1 : 0)
            throw ExecutionHandoff.error(.parameter, "\(name) needs \(minimumParameters)\(procedure.hasRest ? " or more":"") parameters. I found \(parameters.count).")
        }
        
        let parameterValues = try parameters.map { (value) -> Bottom in
            try value.evaluate(context: context)
        }
        
        // Create [paramater name : value] map
        
        let parameterNames = procedure.parameters
        let parameterMap:[String : Bottom]
        
        if procedure.hasRest {
            guard parameterNames.count > 0 else {
                throw ExecutionHandoff.error(.parameter, "\(name) indicates a trailing `rest` parameter, but does not have a name for it.")
            }
            let restIndex = procedure.parameters.count - 1
            let restValue = Array(parameterValues[restIndex...])
            var namedParameterValues = parameterValues[..<restIndex]
            namedParameterValues.append(.list(restValue))
            parameterMap = Dictionary(uniqueKeysWithValues: zip(parameterNames, namedParameterValues))
        } else {
            parameterMap = Dictionary(uniqueKeysWithValues: zip(parameterNames, parameterValues))
        }
        
        return (procedure, parameterMap)
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        
        let (procedure, parameterMap) = try evaluateParameters(in: context)
        
        let newScope: ExecutionContext
        if reuseScope {
            context.inject(procedures: procedure.procedures)
            parameterMap.forEach { (key: String, value: Bottom) in
                context.variables.setLocal(key: key, item: value)
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

//extension ExecutionNode {
//    public func evaluate(context: ExecutionContext) throws -> Bottom {
//        do {
//            try execute(context: context, reuseScope: false)
//        } catch let ExecutionHandoff.output(bottom) {
//            return bottom
//        }
//        throw ExecutionHandoff.error(.noOutput, "No value returned from \(self).")
//    }
//}

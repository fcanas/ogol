//
//  OgoLang.libOgol
//
//  Created by Fabian Canas on 7/20/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Execution

/// The `Meta` module is a place for defining language features that don't require parser
/// modification or support from core exectuion types.
///
/// Procedures are here because they:
/// 1. Require direct access to lower-level features of the runtime not yet exposed by other functions (_e.g._ `thing` isn't a thing yet)
/// 2. There aren't good facilities for data structures yet (these are being added alongside lists).
/// 3. I'm still not in the habit of writing Logo features in a self-hosted fashion.
///
public struct Meta: Module {
    
    public init() { }
    
    public let procedures: [String : Procedure] = [
        "stop":.extern(Meta.stop),
        "make":.extern(Meta.make),
        "local":.extern(Meta.local),
        "output":.extern(Meta.output),
        "if":.extern(Meta.if),
        "run":.extern(Meta.run),
        "item":.extern(Meta.item),
        "count":.extern(Meta.count),
        "invoke":.extern(Meta.invoke),
        "prepend":.extern(Meta.prepend),
        "append":.extern(Meta.append),
    ]
    
    private static var stop: ExternalProcedure = ExternalProcedure(name: "stop", parameters: []) { (_, _) -> Bottom? in
        throw ExecutionHandoff.stop
    }
    
    private static var make: ExternalProcedure = ExternalProcedure(name: "make", parameters: ["symbol", "value"]) { (params, context) -> Bottom? in
        guard case let .reference(symbol, referenceContext) = params[0] else {
            throw ExecutionHandoff.error(.parameter, "make requires its first parameter to be a reference")
        }
        (referenceContext ?? context.parent ?? context).variables[symbol] = params[1]
        return nil
    }
    
    private static var local: ExternalProcedure = ExternalProcedure(name: "local", parameters: ["symbol", "value"]) { (params, context) -> Bottom? in
        guard case let .reference(symbol, _) = params[0] else {
            throw ExecutionHandoff.error(.parameter, "local requires its first parameter to be a reference")
        }
        (context.parent ?? context).variables.setLocal(key: symbol, item: params[1])
        return nil
    }
    
    private static var output: ExternalProcedure = ExternalProcedure(name: "output", parameters: ["value"]) { (params, context) -> Bottom? in
        throw ExecutionHandoff.output(params[0])
    }
    
    private static var `if`: ExternalProcedure = ExternalProcedure(name: "if", parameters: ["condition", "instructionList"]) { (params, context) -> Bottom? in
        guard case let .boolean(condition) = params.first else {
            throw ExecutionHandoff.error(.parameter, "if expects a boolean parameter")
        }
        if condition {
            try run.execute(context: context, reuseScope: true)
        }
        return nil
    }
    
    private static var run: ExternalProcedure = {
        ExternalProcedure(name: "run", parameters: ["instructionList"]) { (params, context) throws -> Bottom? in
            
            let procName: String
            var list: [Bottom]
            
            guard let parameter = params.first else {
                throw ExecutionHandoff.error(.parameter, "run expects a parameter")
            }
            
            switch parameter {
            case var .list(l):
                guard l.count >= 1 else {
                    throw ExecutionHandoff.error(.parameter, "a list passed as a parameter run needs at least one element")
                }
                
                if let executionList = l.asInstructionList() {
                    try executionList.forEach { try $0.execute(context: context, reuseScope: false) }
                    return nil
                }
                
                guard case let .string(p) = l.removeFirst() else {
                    throw ExecutionHandoff.error(.parameter, "The first element of a parameter list run should be the name of a procedure")
                }
                list = l
                procName = p
            case .double(_), .boolean(_):
                throw ExecutionHandoff.output(parameter)
            case let .string(p):
                procName = p
                list = []
            case let .command(command):
                try command.execute(context: context, reuseScope: true)
                return nil
            case .reference(_, _):
                throw ExecutionHandoff.output(parameter)
            }
            
            let invocation = ProcedureInvocation(name: procName, parameters: list.map({Value.bottom($0)}))
            
            do {
                return try invocation.evaluate(context: context)
            } catch ExecutionHandoff.error(.noOutput, _) {
                return nil
            }
        }
    }()
    
    private static var item: ExternalProcedure =
        ExternalProcedure(name: "item", parameters: ["index", "list"]) { (params, context) throws -> Bottom? in
            guard case let .list(list) = params[1] else {
                throw ExecutionHandoff.error(.parameter, "The second parameter of `get` should be a list. Found \n\t\(params[1])")
            }
            guard case let .double(index) = params[0] else {
                throw ExecutionHandoff.error(.parameter, "The first parameter of `get` should be a number. Found \n\t()")
            }
            guard index >= 0 else {
                throw ExecutionHandoff.error(.parameter, "The first parameter of `get` should be greater than zero.")
            }
            let idx = Int(index)
            guard Double(idx) == index else {
                throw ExecutionHandoff.error(.parameter, "The first parameter of `get` should be an integer.")
            }
            
            guard list.count > idx else {
                throw ExecutionHandoff.error(.parameter, "List doesn't have enough elements. Trying to get item at index \(idx) in list with \(list.count) elements.")
            }
            return list[idx]
        }
    
    private static var count: ExternalProcedure =
        ExternalProcedure(name: "count", parameters: ["list"]) { (params, context) throws -> Bottom? in
            guard case let .list(list) = params[0] else {
                throw ExecutionHandoff.error(.parameter, "The first parameter of `count` should be a list. Found \n\t\(params[1])")
            }
            return .double(Double(list.count))
        }
    
    private static var invoke: ExternalProcedure =
        ExternalProcedure(name: "invoke", parameters: ["procedure", "parameters"], hasRest: true) { (params, context) throws -> Bottom? in
            guard case let .reference(procedureName, referenceContext) = params[0] else {
                throw ExecutionHandoff.error(.parameter, "invoke requires its first parameter to be a reference")
            }
            guard let procedure = referenceContext?.procedures[procedureName] else {
                throw ExecutionHandoff.error(.parameter, "No procedure named `\(procedureName)` found.")
            }
            
            // Preprocess Parameters
            let proccessedParameters: [Value]
            if params.count > 1 {
                let rawParameters = params[1]
                if case let .list(parameterList) = rawParameters {
                    proccessedParameters = parameterList.map({ Value.bottom($0) })
                } else {
                    proccessedParameters = [Value.bottom(rawParameters)]
                }
            } else {
                proccessedParameters = []
            }
            
            let invocation = ProcedureInvocation(name: procedureName, parameters: proccessedParameters)
            do {
                try invocation.execute(context: context, reuseScope: false)
            } catch let ExecutionHandoff.output(bottom) {
                return bottom
            }
            return nil
        }
    
    private static var prepend: ExternalProcedure =
        ExternalProcedure(name: "prepend", parameters: ["thing", "list"]) { (params, context) throws -> Bottom? in
            
            let value = params[0]
            
            switch params[1] {
            case let .list(list):
                var finalList = [value]
                finalList.append(contentsOf: list)
                return .list(finalList)
            case let.reference(referenceName, referenceContext):
                let contextToUse = (referenceContext ?? context)
                guard case let .list(list) = context.variables[referenceName] else {
                    throw ExecutionHandoff.error(.parameter, "No list :\(referenceName) visible in the current scope to prepend to.")
                }
                var finalList = [value]
                finalList.append(contentsOf: list)
                contextToUse.variables[referenceName] = .list(finalList)
            default:
                throw ExecutionHandoff.error(.parameter, "The second parameter of `prepend` should be a list or a reference to a list visible from the current scope. Found \n\t\(params[1])")
            }
            return nil
        }
    
    private static var append: ExternalProcedure =
        ExternalProcedure(name: "append", parameters: ["thing", "list"]) { (params, context) throws -> Bottom? in
            
            let value = params[0]
            
            switch params[1] {
            case var .list(list):
                var finalList = [value]
                list.append(value)
                return .list(list)
            case let .reference(referenceName, referenceContext):
                let contextToUse = (referenceContext ?? context)
                guard case var .list(list) = context.variables[referenceName] else {
                    throw ExecutionHandoff.error(.parameter, "No list :\(referenceName) visible in the current scope to append to.")
                }
                list.append(value)
                contextToUse.variables[referenceName] = .list(list)
            default:
                throw ExecutionHandoff.error(.parameter, "The second parameter of `append` should be a list or a reference to a list visible from the current scope. Found \n\t\(params[1])")
            }
            return nil
        }
}

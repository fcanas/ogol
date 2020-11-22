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
                    throw ExecutionHandoff.error(.parameter, "a list passed as a parameter run needs at least one String element")
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
    
}

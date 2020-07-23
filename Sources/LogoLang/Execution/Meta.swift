//
//  Created by Fabian Canas on 7/20/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

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
        "run":.extern(Meta.run),
        // "list":.extern(list) // soon
    ]
    
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
                guard case let .string(p) = l.removeFirst() else {
                    throw ExecutionHandoff.error(.parameter, "The first element of a parameter list run should be the name of a procedure")
                }
                list = l
                procName = p
            case .double(_):
                throw ExecutionHandoff.error(.parameter, "run expects a list or string as a parameter")
            case let .string(p):
                procName = p
                list = []
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

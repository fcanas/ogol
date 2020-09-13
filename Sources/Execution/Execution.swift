//
//  Execution.swift
//  OgoLang.Execution
//
//  Created by Fabián Cañas on 3/2/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

/// Errors are used as a control transfer mechanism.
///
/// `ExecutionHandoff` can represent both normal transfer
/// of control to containing scope, as well as runtime errors.
public enum ExecutionHandoff: Error {

    /// Leaves the current scope. Since there are no loops, it's
    /// mostly just leaving the current procedure or conditional.
    case stop
    
    /// Leaves the current scope, and transforms the calling
    /// expression to a value.
    case output(Bottom)
    
    /// A runtime error from among `Runtime` with additional information.
    case error(Runtime, String) // TODO: node that can be tied back to source?
    
    /// Categories of runtime errors
    public enum Runtime {
        /// An operation was attempted on a `Bottom` type that does not support the operation. _e.g._ arithmetic on strings
        case typeError
        /// A given symbol was not found in the context
        case missingSymbol
        /// Something went wrong relating to a parameter to a procedure
        case parameter
        /// The maximum depth of nested `ExecutionContext` has been reached.
        /// The limit can be dynamically adjusted via `ExecutionContext.MaxDepth`,
        /// lower values can prevent crashes.
        case maxDepth
        /// A procedure invocation that was expected to generate output did not generate output.
        case noOutput
        /// To be used by modules to report runtime errors that do not fit into existing categories.
        case module
    }
}

public struct Program: Codable {
    
    public var description: String = "Program" // TODO

    public var commands: [ExecutionNode]

    public var procedures: [String : Procedure]

    public init(executionNodes: [ExecutionNode], procedures:[Procedure]) {
        var p: [String : Procedure] = [:]
        procedures.forEach { (procedure) in
            p[procedure.name] = procedure
        }
        self.commands = executionNodes
        self.procedures = p
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let context: ExecutionContext = reuseScope ? context : try ExecutionContext(parent: context, procedures: procedures)
        for command in commands {
            try command.execute(context: context, reuseScope: false)
        }
    }
}




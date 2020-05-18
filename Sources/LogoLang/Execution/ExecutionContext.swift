//
//  ExecutionContext.swift
//  FFCParserCombinator
//
//  Created by Fabián Cañas on 4/24/20.
//

import Foundation

public class ExecutionContext: TurtleCommandSource {

    public func load(_ module: Module.Type) {
        inject(procedures: module.procedures)
    }

    public func inject(procedures: [String:Procedure]) {
        procedures.forEach { (key: String, value: Procedure) in
            self.procedures.items[key] = value
        }
    }
    
    public static var MaxDepth: Int = 500

    public var issueCommand: (Turtle.Command) -> Void

    class NestedKeyValueStore<T> {
        var parent: NestedKeyValueStore<T>?
        var items: [String : T]
        subscript(key: String)-> T? {
            get {
                return items[key] ?? parent?[key]
            }
            set(item) {
                // This means there's no shadowing.
                // If a symbol has a value in an enclosing scope,
                // it will be set in the outer scope
                (listContaining(key: key) ?? self).items[key] = item
            }
        }
        func listContaining(key: String) -> NestedKeyValueStore? {
            if items[key] != nil {
                return self
            }
            return parent?.listContaining(key: key)
        }
        init(parent: NestedKeyValueStore<T>?, items: [String: T] = [:]) {
            self.parent = parent
            self.items = items
        }

        // MARK: Inspection

        func allKeys() -> [String] {
            return (parent.map { store -> [String] in
                store.allKeys()
            } ?? []) + Array(items.keys)
        }

        func flattened() -> [String:T] {
            allKeys().reduce(Dictionary<String, T>()) { (r, key) -> Dictionary<String, T> in
                var mr = r
                mr[key] = self[key]
                return mr
            }
        }
    }

    var procedures: NestedKeyValueStore<Procedure>
    var variables: NestedKeyValueStore<Bottom>
    private var depth: Int

    public func allVariables() -> [String:Bottom] {
        return variables.flattened()
    }

    public func allProcedures() -> [String:Procedure] {
        return procedures.flattened()
    }

    // Single child, expecint more of a linked list for nested scopes rather than trees?
    // Rethink execution to support stepping, etc.
    var child: ExecutionContext?

    public func deepestChild() -> ExecutionContext {
        return child?.deepestChild() ?? self
    }

    /// Initialized a root execution context.
    ///
    /// The resulting context will have no parent.
    ///
    /// - Parameters:
    ///   - procedures: Procedures that are newly available at this scope.
    ///   - variables: Variables that are newly available at this scope.
    public convenience init(procedures: [String:Procedure] = [:], variables: [String:Bottom] = [:]) {
        // As long as the designated initializer only throws on exceeding stack depth
        // this will always succeed.
        try! self.init(parent: nil, procedures: procedures, variables: variables)
    }

    /// Initializes a new `ExecutionContext`, which serves as a scope.
    /// - Parameters:
    ///   - parent:     The parent execution context. Procedures and variables defined
    ///                 in the parent scope (recursively) are available to chil contexts.
    ///   - procedures: Procedures that are newly available at this scope.
    ///                 It is not necessary, and probably an error to pass procedures
    ///                 that already exist in the parent scope.
    ///   - variables:  Variables that are newly available at this scope.
    ///                 It is not necessary, and probably an error to pass variables
    ///                 that already exist in the parent scope unless they are explicitly
    ///                 local, and will shadow the previous variable.
    /// - Throws:       Instantiating an `ExecutionContext` will throw the error
    ///                 `ExecutionHandoff.error(.maxDepth,...)` if adding the new
    ///                 context as a child of `parent` would create a single context
    ///                 chain deeper than `ExecutionContext.MaxDepth`.
    public init(parent: ExecutionContext?, procedures: [String:Procedure] = [:], variables: [String:Bottom] = [:]) throws {
        self.depth = parent.map({ $0.depth + 1 }) ?? 0
        if self.depth > ExecutionContext.MaxDepth {
            throw ExecutionHandoff.error(.maxDepth, "Number of execution contexts exceeded")
        }
        self.procedures = NestedKeyValueStore(parent: parent?.procedures, items: procedures)
        self.variables = NestedKeyValueStore(parent: parent?.variables, items: variables)
        self.issueCommand = { [weak parent] t in parent?.issueCommand(t) }
        parent?.child = self
    }
}

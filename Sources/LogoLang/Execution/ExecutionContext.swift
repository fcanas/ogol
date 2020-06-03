//
//  ExecutionContext.swift
//  FFCParserCombinator
//
//  Created by Fabián Cañas on 4/24/20.
//

import Foundation

public class ExecutionContext {
    
    private weak var _root: ExecutionContext!
    
    public struct ModuleKey<T> {
        let key: String
    }

    public class ModuleStore {
        private var store: [String:Any] = [:]
        subscript<T>(key: ModuleKey<T>) -> T? {
            get {
                return store[key.key] as? T
            }
            set {
                store[key.key] = newValue
            }
        }
    }

    public func load(_ module: Module.Type) {
        if let p = parent {
            p.load(module)
            return
        }
        inject(procedures: module.procedures)
        module.initialize(context: self)
    }

    public func inject(procedures: [String:Procedure]) {
        procedures.forEach { (key: String, value: Procedure) in
            self.procedures.items[key] = value
        }
    }
    
    public static var MaxDepth: Int = 500

    public class NestedKeyValueStore<T> {
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
    var moduleStores: NestedKeyValueStore<ModuleStore>
    private var depth: Int
    private weak var parent: ExecutionContext?

    public func allVariables() -> [String:Bottom] {
        return variables.flattened()
    }

    public func allProcedures() -> [String:Procedure] {
        return procedures.flattened()
    }

    /// Initialized a root execution context.
    ///
    /// The resulting context will have no parent.
    ///
    /// - Parameters:
    ///   - procedures: Procedures that are newly available at this scope.
    ///   - variables: Variables that are newly available at this scope.
    public init(procedures: [String:Procedure] = [:], variables: [String:Bottom] = [:]) {
        self.depth = 0
        
        self.procedures = NestedKeyValueStore(parent: nil, items: procedures)
        self.variables = NestedKeyValueStore(parent: nil, items: variables)
        
        self.moduleStores = NestedKeyValueStore(parent: nil, items: [:])
        _root = self
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
    public init(parent: ExecutionContext, procedures: [String:Procedure] = [:], variables: [String:Bottom] = [:]) throws {
        self.depth = parent.depth + 1
        if depth > ExecutionContext.MaxDepth {
            throw ExecutionHandoff.error(.maxDepth, "Number of execution contexts exceeded")
        }
        
        if procedures.count != 0 {
            self.procedures = NestedKeyValueStore(parent: parent.procedures, items: procedures)
        } else {
            self.procedures = parent.procedures
        }
        
        self.variables = NestedKeyValueStore(parent: parent.variables, items: variables)
        
        self.parent = parent
        self.moduleStores = parent._root.moduleStores
        _root = parent._root
    }
    
}

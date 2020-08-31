//
//  ExecutionContext.swift
//  LogoLang.Execution
//
//  Created by Fabián Cañas on 4/24/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public class ExecutionContext {
    
    /// The maximum stack depth of `ExecutionContext`s allowed.
    /// Exceeding `MaxDepth` throws an error, which may be preferable to crashing.
    public static var MaxDepth: UInt = 500
    
    /// A static block called with the current stack depth whenever a new stack frame (`ExecutionContext`) is 
    public static var StackDepthProbe: ((UInt) -> Void)?
    private var depth: UInt
    
    public var procedures: NestedKeyValueStore<Procedure>
    public var variables: NestedKeyValueStore<Bottom>
    public var moduleStores: NestedKeyValueStore<ModuleStore>
    
    public weak var parent: ExecutionContext?
    private weak var _root: ExecutionContext!

    public class ModuleStore {
        
        public struct Key<T> {
            public init(key: String) {
                self.key = key
            }
            let key: String
        }
        
        public init() {
            store = [:]
        }
        private var store: [String:Any] = [:]
        public subscript<T>(key: Key<T>) -> T? {
            get {
                return store[key.key] as? T
            }
            set {
                store[key.key] = newValue
            }
        }
    }
    
    /// Loads the provided `Module` into the runtime's root `ExecutionContext`.
    ///
    /// The `Module`'s procedures will be `inject`ed such that they are available
    /// to all `ExectuionContext` with the same root ancestor. The `Module`
    /// will also have `initialize(context:)` called with the root `ExecutionContext`
    /// as the parameter.
    ///
    /// - Parameter module: The `Module` to load.
    public func load(_ module: Module) {
        if let p = parent {
            p.load(module)
            return
        }
        inject(procedures: module.procedures)
        module.initialize(context: self)
    }
    
    /// Injects the passed `Procedures` into the `ExecutionContext`, making them
    /// available for invocation in this `ExecutionContext` and in child contexts. The
    /// procedures are not available in parent `ExectionContext`s. When this
    /// `ExecutionContext` is destroyed, the runtime may no longer have a reference
    /// to the procedures.
    /// - Parameter procedures: A map of `[ProcedureName:Procedure]` to
    /// make available in this `ExecutionContext` and its children.
    public func inject(procedures: [String:Procedure]) {
        procedures.forEach { (key: String, value: Procedure) in
            self.procedures.items[key] = value
        }
    }
    
    /// All variables as viewed from the receiving `ExecutionContext`
    /// - Returns: A map of all the variables visible from the receiving `ExecutionContext`'s scope.
    public func allVariables() -> [String:Bottom] {
        return variables.flattened()
    }

    /// All `Procedure`s as viewed from the receiving `ExecutionContext`
    /// - Returns: A map of all the `Procedure`s visible from the receiving `ExecutionContext`'s scope.
    public func allProcedures() -> [String:Procedure] {
        return procedures.flattened()
    }

    /// Initializes a root execution context.
    ///
    /// The resulting context will have no parent.
    ///
    /// - Parameters:
    ///   - procedures: Procedures that are newly available at this scope.
    ///   - variables: Variables that are newly available at this scope.
    ///   - modules: Modules for this context to load, making those modules available at this and all child scopes.
    public init(procedures: [String:Procedure] = [:], variables: [String:Bottom] = [:], modules: [Module] = []) {
        self.depth = 0
        
        self.procedures = NestedKeyValueStore(parent: nil, items: procedures)
        self.variables = NestedKeyValueStore(parent: nil, items: variables)
        
        self.moduleStores = NestedKeyValueStore(parent: nil, items: [:])
        _root = self
        modules.forEach { self.load($0) }
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
        ExecutionContext.StackDepthProbe?(self.depth)
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

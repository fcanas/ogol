//
//  ExecutionContext.swift
//  FFCParserCombinator
//
//  Created by Fabián Cañas on 4/24/20.
//

import Foundation

public class ExecutionContext: TurtleCommandSource {

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
    var variables: NestedKeyValueStore<Double>

    public func allVariables() -> [String:Double] {
        return variables.flattened()
    }

    // Single child, expecint more of a linked list for nested scopes rather than trees?
    // Rethink execution to support stepping, etc.
    var child: ExecutionContext?

    public func deepestChild() -> ExecutionContext {
        return child?.deepestChild() ?? self
    }

    public init(parent: ExecutionContext?, procedures: [String:Procedure] = [:], variables: [String:Double] = [:]) {
        self.procedures = NestedKeyValueStore(parent: parent?.procedures, items: procedures)
        self.variables = NestedKeyValueStore(parent: parent?.variables, items: variables)
        self.issueCommand = { [weak parent] t in parent?.issueCommand(t) }
        parent?.child = self
    }
}

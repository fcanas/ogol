//
//  NestedKeyValueStore.swift
//  OgoLang.Execution.NestedKeyValueStore
//
//  Created by Fabian Canas on 8/17/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

/// A nestable dictionary-like object implementing dynamic scope.
///
/// When getting a value for a key, if the store does not find the value
/// within itself directly, it will recursively check its parent. When setting
/// a value for a key, first the hierarchy is checked for a store containing
/// a value for the provided key, then the first found entry for the key is
/// overwritten with the new value. When writing a value, if no existing
/// entry for the key is found, the receiving store will write the value.
public class NestedKeyValueStore<T, C: AnyObject> {
    weak var container: C?
    /// The parent store, or `nil` if a root store.
    var parent: NestedKeyValueStore<T,C>?
    /// The backing dictionary for the store.
    internal var items: [String : T]
    public subscript(key: String)-> T? {
        get {
            return items[key] ?? parent?[key]
        }
        set(item) {
            // This means there's no shadowing via subscripting.
            // If an enclosing scope has a value for the key, the
            // new value will be set at that scope, not the first
            // receiver.
            (storeContaining(key: key) ?? self).items[key] = item
        }
    }
    
    /// Sets the value for `key` to item on the receiving value store.
    /// This does _not_ attempt to set it on a parent store, regardless of whether a value
    /// for the key exists locally. The value can be retrieved via standard subscripting.
    /// - Parameters:
    ///   - key: key to set
    ///   - item: item to set for the given key
    public func setLocal(key: String, item: T) {
        self.items[key] = item
    }
    
    /// Recursively finds the nearest `NestedKeyValueStore` containing a value
    /// for the supplied key, starting with `self`.
    /// - Parameter key: key to probe
    /// - Returns: The nearest ancestor `NestedKeyValueStore` (starting with `self`) with a defined value for `key`
    func storeContaining(key: String) -> NestedKeyValueStore? {
        if items[key] != nil {
            return self
        }
        return parent?.storeContaining(key: key)
    }
    
    /// Initializes a `NestedKeyValueStore` with a parent, and a mapping of items to
    /// be defined in the new scope.
    ///
    /// Key-values defined in `items` are injected directly into the new scope. If a `key`
    /// is defined in a scope up the chain via `parent`, the enclosing scopes will not be
    /// affected. Unlike direct subscripting into a `NestedKeyValueStore` instance, this
    /// injection mechanism in the initializer represents a way to introduce shadowing.
    ///
    /// - Parameters:
    ///   - parent: The parent store, or `nil` if defining a root store. Stores will
    ///   recursively search their parents for values until a value for a key is found.
    ///   - items: Key-value pairs for the new store. They can be retreived or overwritten
    ///   by subscript access to the store.
    init(parent: NestedKeyValueStore<T,C>?, items: [String: T] = [:], container: C? = nil) {
        self.parent = parent
        self.items = items
        self.container = container
    }

    // MARK: - Inspection
    
    /// Keys for all the values visible in this store, recursively through parents
    /// - Returns: All keys readable from this store with a value.
    func allKeys() -> [String] {
        return parent?.allKeys() ?? [] + Array(items.keys)
    }
    
    /// Builds a single dictionary representing the world visible from the store. Every key-value
    /// gettable by the store will have a single entry representing the value in the closest store.
    /// With this snapshot, all context about where in the nesting stores the value came from is
    /// lost.
    /// - Returns: A dictionary with all the key-values reachable by this store
    internal func flattened() -> [String:T] {
        allKeys().reduce(Dictionary<String, T>()) { (r, key) -> Dictionary<String, T> in
            var mr = r
            mr[key] = self[key]
            return mr
        }
    }
}

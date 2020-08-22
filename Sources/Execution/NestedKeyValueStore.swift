//
//  NestedKeyValueStore.swift
//  LogoLang.NestedKeyValueStore
//
//  Created by Fabian Canas on 8/17/20.
//


public class NestedKeyValueStore<T> {
    var parent: NestedKeyValueStore<T>?
    var items: [String : T]
    public subscript(key: String)-> T? {
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

    // MARK: - Inspection

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

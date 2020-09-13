//
//  Bottom.swift
//  OgoLang.Execution
//
//  Created by Fabian Canas on 6/6/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public enum Bottom {
    case double(Double)
    case string(String)
    case boolean(Bool)
    indirect case command(ExecutionNode)
    indirect case list([Bottom])
}

extension Bottom: Equatable {

    public static func == (lhs: Bottom, rhs: Bottom) -> Bool {
        switch (lhs, rhs) {
        case let (.double(l), .double(r)):
            return l == r
        case let (.string(l), .string(r)):
            return l == r
        case let (.list(l), .list(r)):
            return l == r
        case let (.boolean(l), .boolean(r)):
            return l == r
        case let (.command(l), .command(r)):
            return l == r
        case (.string(_), .double(_)),
             (.double(_), .string(_)),
             (.list(_), .double(_)),
             (.boolean(_), .double(_)),
             (.boolean(_), .string(_)),
             (.boolean(_), .list(_)),
             (.double(_), .boolean(_)),
             (.string(_), .boolean(_)),
             (.list(_), .boolean(_)),
             (.list(_), .string(_)),
             (.double(_), .list(_)),
             (.string(_), .list(_)),
             (.command(_), .string(_)),
             (.command(_), .boolean(_)),
             (.command(_), .list(_)),
             (.boolean(_), .command(_)),
             (.list(_), .command(_)),
             (.string(_), .command(_)),
             (.double(_), .command(_)),
             (.command(_), .double(_)):
            return false
        }
    }
}

extension Bottom: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .double(d):
            return "\(d)"
        case let .string(s):
            return s
        case let .list(l):
            return "[" + l.map{ $0.description }.joined(separator: ", ") + "]"
        case let .boolean(b):
            return b ? "true" : "false"
        case let .command(c):
            return c.description
        }
    }
}

public enum LogoCodingError: Error {
    case bottom
    case signExpression
    case value
    case procedure
    case ExecutionNode
    case logicalExpression
}

extension Bottom: Codable {
    
    enum Key: CodingKey {
        case double
        case string
        case list
        case bool
        case command
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        if let rawValue = try container.decodeIfPresent(Double.self, forKey: .double) {
            self = .double(rawValue)
            return
        } else if let rawValue = try container.decodeIfPresent(String.self, forKey: .string) {
            self = .string(rawValue)
            return
        } else if let rawValue = try container.decodeIfPresent(Array<Bottom>.self, forKey: .string) {
            self = .list(rawValue)
            return 
        } else if let rawValue = try container.decodeIfPresent(Bool.self, forKey: .bool) {
            self = .boolean(rawValue)
            return
        } else if let rawValue = try container.decodeIfPresent(ExecutionNode.self, forKey: .command) {
            self = .command(rawValue)
            return
        }
        throw LogoCodingError.bottom
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .double(doubleValue):
            try container.encode(doubleValue, forKey: .double)
        case let .string(stringValue):
            try container.encode(stringValue, forKey: .string)
        case let .list(listValue):
            try container.encode(listValue, forKey: .list)
        case let .boolean(boolValue):
            try container.encode(boolValue, forKey: .bool)
        case let .command(commandValue):
            try container.encode(commandValue, forKey: .command)
        }
    }
    
}

//
//  File.swift
//  LogoLang
//
//  Created by Fabian Canas on 6/6/20.
//

import Foundation

public enum Bottom: Equatable {

    public static func == (lhs: Bottom, rhs: Bottom) -> Bool {
        switch (lhs, rhs) {
        case let (.double(l), .double(r)):
            return l == r
        case let (.string(l), .string(r)):
            return l == r
        case let (.list(l), .list(r)):
            return l == r
        case (.string(_), .double(_)),
             (.double(_), .string(_)),
             (.list(_), .double(_)),
             (.list(_), .string(_)),
             (.string(_), .list(_)),
             (.double(_), .list(_)):
            return false
        }
    }

    case double(Double)
    case string(String)
    indirect case list([Bottom])
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
        }
    }
}

public enum LogoCodingError: Error {
    case bottom
    case signExpression
    case value
    case procedure
    case ExecutionNode
}

extension Bottom: Codable {
    
    enum Key: CodingKey {
        case double
        case string
        case list
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
        }
    }
    
}

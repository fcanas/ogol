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
        case (.string(_), .double(_)), (.double(_), .string(_)):
            return false
        }
    }

    case double(Double)
    case string(String)
}

extension Bottom: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .double(d):
            return "\"\(d)\""
        case let .string(s):
            return s
        }
    }
}

extension Bottom: Codable {
    
    enum Key: CodingKey {
        case rawValue
        case associatedValue
    }
    
    enum BottomCodingError: Error {
        case unknownCase
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        switch rawValue {
        case "double":
            let doubleValue = try container.decode(Double.self, forKey: .associatedValue)
            self = .double(doubleValue)
        case "string":
            let stringValue = try container.decode(String.self, forKey: .associatedValue)
            self = .string(stringValue)
        default:
            throw BottomCodingError.unknownCase
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case let .double(doubleValue):
            try container.encode("double", forKey: .rawValue)
            try container.encode(doubleValue, forKey: .associatedValue)
        case let.string(stringValue):
            try container.encode("string", forKey: .rawValue)
            try container.encode(stringValue, forKey: .associatedValue)
        }
    }
    
}

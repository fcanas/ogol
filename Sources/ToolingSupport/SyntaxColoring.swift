//
//  SyntaxColoring.swift
//  LogoLang
//
//  Created by Fabián Cañas on 4/11/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Execution

public enum SyntaxCategory {
    case plain
    case number
    case variable
    case procedureInvocation
    case procedureDefinition
    case parameterDeclaration
    case operation
    case keyword
    case builtin
    case comment
    case stringLiteral
}

public protocol SyntaxColorable {
    func syntaxCategory() -> SyntaxCategory?
}

public struct SyntaxType: SyntaxColorable {
    public init(category: SyntaxCategory) {
        self.category = category
    }
    
    let category: SyntaxCategory
    public func syntaxCategory() -> SyntaxCategory? {
        return category
    }
}

extension Value: SyntaxColorable {
    public func syntaxCategory() -> SyntaxCategory? {
        switch self {
        case let .bottom(b):
            switch b {
            case .string(_):
                return .stringLiteral
            case .double(_):
                return .number
            case .list(_):
                // Lists should probably be transparent to let contained values be shown?
                return nil
            case .boolean(_):
                return .keyword
            case .command(_):
                return nil
            }
        case .deref(_):
            return .variable
        case .expression(_):
            return nil
        case .procedure(_):
            fatalError("This shouldn't be here")
        }
    }
}

extension ProcedureInvocation: SyntaxColorable {
    public func syntaxCategory() -> SyntaxCategory? {
        return .procedureInvocation
    }
}


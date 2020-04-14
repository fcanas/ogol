//
//  SyntaxColoring.swift
//  LogoLang
//
//  Created by Fabián Cañas on 4/11/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation

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

struct SyntaxType: SyntaxColorable {
    let category: SyntaxCategory
    func syntaxCategory() -> SyntaxCategory? {
        return category
    }
}

extension Value: SyntaxColorable {
    func syntaxCategory() -> SyntaxCategory? {
        switch self {
        case .number(_):
            return .number
        case .deref(_):
            return .variable
        case .expression(_):
            return nil
        }
    }
}


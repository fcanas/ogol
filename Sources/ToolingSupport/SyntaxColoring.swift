//
//  SyntaxColoring.swift
//  OgoLang
//
//  Created by Fabián Cañas on 4/11/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

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

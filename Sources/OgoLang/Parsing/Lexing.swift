//
//  Lexing.swift
//  OgoLang
//
//  Created by Fabián Cañas on 4/11/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Execution
import FFCParserCombinator
import Foundation
import ToolingSupport

extension CharacterSet {
    static let symbotStart = CharacterSet.letters.union(CharacterSet(charactersIn: "._"))
    static let symbolAny = symbotStart.union(CharacterSet(charactersIn: "0"..."9"))
}

// MARK: Lex

struct Lex {
    static let stringLiteral: Parser<Substring, String> = Lex.Token.stringLiteral
    static let to: Parser<Substring, String> = "to"
    static let name: Parser<Substring, String> = Lex.Token.name
    static let end: Parser<Substring, String> = "end"

    static let listStart: Parser<Substring, String> = "["
    static let listEnd: Parser<Substring, String> = "]"
    
    static let paramaterSeparator: Parser<Substring, String> = "," <* Token._w

    static let comment: Parser<Substring, String> = Lex.Token.comment

    struct Token {

        static let stringLiteral = "\"" *> string <* "\""
        static let reference = { Value.reference($0) } <^> ":" *> name
        static let lookup = { Value.deref($0) } <^> name
        static let string = { (c) -> String in
            return String(c)
        } <^> CharacterSet(charactersIn: "\"").inverted.parser().many
        
        static let name = { (c, ca) -> String in
            return String(c) + String(ca)
            } <^> CharacterSet.symbotStart.parser() <&> CharacterSet.symbolAny.parser().many
        static let number = { Value.bottom(.double(($0))) } <^> Double.parser
        static let comment = { String($0) } <^> ";" *> character(condition: { $0 != "\n" && $0 != "\r" }).many <* eol
        static let eol = _w *> BasicParser.newline.many
        static let _space = CharacterSet.whitespaces.parser().many1
        static let _w = CharacterSet.whitespaces.parser().many

        static let skipToNextLine = { String($0) } <^> character(condition: { $0 != "\n" && $0 != "\r" }).many <* eol
    }
}

// MARK: Operators

/// A protocol that ought to be able to be trivially adopted by a type defining an `Operator`.
///
/// Default implementations give the `Operator` types appropriate syntax coloring/categorization behavior,
/// and a reasonable generated parser for `Operator` types that are `RawRepresentable` by  a `Character`.
protocol Op: SyntaxColorable {}

extension Op {
    func syntaxCategory() -> SyntaxCategory? {
        return .operation
    }
}

extension Op where Self: RawRepresentable, Self.RawValue == Character, Self: CaseIterable {

    static var parser: Parser<Substring, Self> {
        let combinedParser = self.allCases.reduce(nil) { (parser, op) -> Parser<Substring, String>? in
            let nextP = ({ String($0) } <^> character { op.rawValue == $0 })
            if parser == nil {
                return nextP
            } else {
                return parser! <|> nextP
            }
        }!
        return { self.init(rawValue: $0.first!)! } <^>  Lex.Token._w *> combinedParser
    }
}

enum AdditionOperator: Character, CaseIterable, Op {

    case add = "+"
    case subtract = "-"

    var additionOperator: ArithmeticExpression.Operation {
        get {
            switch self {
            case .add:
                return .add
            case .subtract:
                return .subtract
            }
        }
    }
}

enum MultiplicationOperator: Character, CaseIterable, Op {

    case multiply = "*"
    case divide = "/"

    var multiplyingOperator: MultiplyingExpression.Operation {
        get {
            switch self {
            case .multiply:
                return .multiply
            case .divide:
                return .divide
            }
        }
    }
}

enum ComparisonOperator: Character, CaseIterable, Op {
    case lt = "<"
    case gt = ">"
    case eq = "="

    var comparisonOperator: Expression.Operation {
        get {
            switch self {
            case .lt:
                return .lt
            case .gt:
                return .gt
            case .eq:
                return .eq
            }
        }
    }
}

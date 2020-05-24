//
//  Lexing.swift
//  LogoLang
//
//  Created by Fabián Cañas on 4/11/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation
import FFCParserCombinator

extension CharacterSet {
    static let logoAlphabetical = CharacterSet.letters
    static let logoAlphaNumeric = logoAlphabetical.union(CharacterSet(charactersIn: "0"..."9"))
}

// MARK: Lex

struct Lex {
    static let stringLiteral: Parser<Substring, String> = Lex.Token.stringLiteral
    static let to: Parser<Substring, String> = "to"
    static let name: Parser<Substring, String> = Lex.Token.string
    static let end: Parser<Substring, String> = "end"

    static let blockStart: Parser<Substring, String> = "["
    static let blockEnd: Parser<Substring, String> = "]"

    static let comment: Parser<Substring, String> = Lex.Token.comment

    struct Commands {

        enum ControlFlow: SyntaxColorable {
            func syntaxCategory() -> SyntaxCategory? {
                switch self {
                case .repeat_, .make, .ife, .stop, .output:
                    return .keyword
                case .procedureInvocation(_):
                    return .procedureInvocation
                }
            }

            case repeat_
            case make
            case procedureInvocation(String)
            case ife
            case stop
            case output
            // TODO: case fore
            // TODO: case label
        }

        static let expressionless = (cs <|> pu <|> pd <|> ht <|> st <|> home) <* Lex.Token._space.optional

        static let cs: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.cs } <^> ("cs" <|> "clearscreen") <* (Lex.Token._space  <|>  Lex.Token.eol)
        static let pu: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.pu } <^> ("pu" <|> "penup") <* (Lex.Token._space  <|>  Lex.Token.eol)
        static let pd: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.pd } <^> ("pd" <|> "pendown") <* (Lex.Token._space  <|>  Lex.Token.eol)
        static let ht: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.ht } <^> ("ht" <|> "hide") <* (Lex.Token._space  <|>  Lex.Token.eol)
        static let st: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.st } <^> ("st" <|> "show") <* (Lex.Token._space  <|>  Lex.Token.eol)
        static let home: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.home } <^> "home" <* (Lex.Token._space  <|> Lex.Token.eol)

        static let singleExpression = (fd <|> bk <|> rt <|> lt) <* Lex.Token._space

        static let fd: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.fd } <^> ("fd" <|> "forward")
        static let bk: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.bk } <^> ("bk" <|> "backward" <|> "back")
        static let rt: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.rt } <^> ("rt" <|> "right")
        static let lt: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.lt } <^> ("lt" <|> "left")
        static let setxy: Parser<Substring, Turtle.Command.Partial> = { _ in Turtle.Command.Partial.setxy } <^> "setxy" <* Lex.Token._space

        static let controlFlow = ((repeat_ <|> make <|> ife) <* Lex.Token._space) <|> stop <|> output <|> procedureInvocation

        static let repeat_: Parser<Substring, Lex.Commands.ControlFlow> = { _ in Lex.Commands.ControlFlow.repeat_ } <^> "repeat"
        static let make: Parser<Substring, Lex.Commands.ControlFlow> = { _ in Lex.Commands.ControlFlow.make } <^> "make"
        static let ife: Parser<Substring, Lex.Commands.ControlFlow> = { _ in Lex.Commands.ControlFlow.ife } <^> "if"
        static let stop: Parser<Substring, Lex.Commands.ControlFlow> = { _ in Lex.Commands.ControlFlow.stop } <^> "stop"
        static let output: Parser<Substring, Lex.Commands.ControlFlow> = { _ in Lex.Commands.ControlFlow.output } <^> "output"

        static let procedureInvocation = { Lex.Commands.ControlFlow.procedureInvocation($0) } <^> Lex.name

        static let turtle = expressionless <|> singleExpression <|> setxy
    }

    struct Token {

        static let stringLiteral = "\"" *> string
        static let deref = { Value.deref($0) } <^> ":" *> string
        static let string = { (c, ca) -> String in
            return String(c) + String(ca)
            } <^> CharacterSet.logoAlphabetical.parser() <&> CharacterSet.logoAlphaNumeric.parser().many
        static let number = { Value.number($0) } <^> Double.parser
        static let comment = { String($0) } <^> ";" *> character(condition: { $0 != "\n" && $0 != "\r" }).many <* eol
        static let eol = _w *> BasicParser.newline.many
        static let _space = CharacterSet.whitespaces.parser().many1
        static let _w = CharacterSet.whitespaces.parser().many

        static let skipToNextLine = { String($0) } <^> character(condition: { $0 != "\n" && $0 != "\r" }).many <* eol
    }
}

// MARK: Operators

protocol Op: SyntaxColorable{}

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

    var additionOperator: Expression.ExpressionOperation {
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

    var multiplyingOperator: MultiplyingExpression.MultiplyingOperation {
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

    var additionOperator: Conditional.Comparison {
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

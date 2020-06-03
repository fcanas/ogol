//
//  Parser.swift
//  Logo
//
//  Created by Fabián Cañas on 3/7/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation
import FFCParserCombinator

enum Either<A, B>{
    case left(A)
    case right(B)
}

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}

public class LogoParser {

    // MARK: - Types

    public enum ParseError {
        case basic(String)
        case anticipatedRuntime(String)
        case severeInternal(String)
    }

    public enum ParseResult {
        case success(Program, [Range<Substring.Index>:SyntaxColorable], [Range<Substring.Index>:ParseError])
        case error([Range<Substring.Index>:ParseError])
    }

    public init() {}

    public func program(substring: Substring) -> ParseResult {

        hasFatalError = false
        errors = [:]
        allTokens = [:]

        var runningSubstring = eatNewlines(substring)
        var executionNodes: [ExecutionNode] = []
        while let parsedLine = line(substring: runningSubstring) {
            switch parsedLine.0 {
            case let .left(x):
                executionNodes.append(x)
            case let .right(x):
                executionNodes.append(x)
            }
            runningSubstring = eatNewlines(parsedLine.1)
        }

        if hasFatalError {
            return .error(self.errors)
        }
        let program = Program(executionNodes: executionNodes)
        verifyProcedureCalls(for: program)

        return .success(program, self.allTokens, self.errors)
    }

    // MARK: - Bookeeping and State Accumulation

    internal var allTokens: [Range<Substring.Index>:SyntaxColorable] = [:]

    private var hasFatalError: Bool = false

    private func registerToken(range: Range<Substring.Index>, token: SyntaxColorable) {
        if hasFatalError {
            return
        }
        allTokens[range] = token
    }

    private var errors: [Range<Substring.Index>:ParseError] = [:] {
        didSet {
            #if DEBUG
            errors.forEach { (key, _) in
                assert(key.upperBound != key.lowerBound, "Ranges should be non-zero")
            }
            #endif
        }
    }

    // MARK: - Verify

    func verifyProcedureCalls(for program: Program) {
        allTokens.forEach { (range: Range<Substring.Index>, value: SyntaxColorable) in
            switch value.syntaxCategory() {
            case .procedureInvocation:
                guard let invocation = value as? ProcedureInvocation else {
                    break
                }

                let procedureName = invocation.name
                
                if let procedure = program.procedures[procedureName] {
                    let invocationCount = invocation.parameters.count
                    let declarationCount = procedure.parameters.count
                    if invocationCount != declarationCount {
                        errors[range] = .anticipatedRuntime("Procedure '\(procedureName)' invoked with \(invocationCount) parameters but declared with \(declarationCount) parameters")
                    }
                } else {
                    errors[range] = .anticipatedRuntime("Cannot find implementation for '\(procedureName)'")
                }
            default:
                break;
            }
        }
    }

    // MARK: - Parse

    private func line(substring: Substring) -> (Either<Procedure, Command>, Substring)? {
        var previous: Substring
        var skipCommentLine = substring
        repeat {
            previous = skipCommentLine
            skipCommentLine = eatComment(skipCommentLine)
        } while (previous != skipCommentLine)

        if let procedure = procedureDeclaration(substring: skipCommentLine) {
            return (Either.left(procedure.0), procedure.1)
        }
        if let command = command(substring: skipCommentLine) {
            let runningSubstring = eatNewlines(eatComment(command.1))
            return (Either.right(command.0), runningSubstring)
        }
        return nil
    }

    private func procedureDeclaration(substring: Substring) -> (Procedure, Substring)? {
        var runningSubstring = substring
        guard let lexedProcedure = Lex.to.run(runningSubstring) else {
            // No procedure found. Ok.
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<lexedProcedure.1.startIndex, token: SyntaxType(category: .keyword))
        runningSubstring = eatWhitespace(lexedProcedure.1)
        guard let lexedName = Lex.name.run(runningSubstring) else {
            errors[substring.startIndex..<runningSubstring.startIndex] = .basic("Expected name for declared procedure")
            hasFatalError = true
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<lexedName.1.startIndex, token: SyntaxType(category: .procedureDefinition))
        runningSubstring = eatNewlines(lexedName.1)

        let parameterTokenizer = { (value: Value) -> Value in
            switch value {
            case .deref(_):
                break
            default:
                self.errors[substring.startIndex..<runningSubstring.startIndex] = .severeInternal("Parameter names must be declared as a deref value")
                self.hasFatalError = true
            }
            return value
            } <^> Lex.Token.deref

        var parameters: [Value] = []
        if let param = parameterTokenizer.run(runningSubstring) {
            registerToken(range: runningSubstring.startIndex..<param.1.startIndex, token: SyntaxType(category: .parameterDeclaration))
            parameters.append(param.0)
            runningSubstring = param.1
            while let nextParam = ("," *> Lex.Token._space *> parameterTokenizer).run(runningSubstring) {
                registerToken(range: runningSubstring.startIndex..<nextParam.1.startIndex, token: SyntaxType(category: .parameterDeclaration))
                parameters.append(nextParam.0)
                runningSubstring = nextParam.1
            }
        }

        runningSubstring = eatNewlines(runningSubstring)

        var commands: [Command] = []
        var subProcedures: [String : Procedure] = [:]
        while let nextLine = line(substring: runningSubstring) {
            switch nextLine.0 {
            case let .left(proc):
                subProcedures[proc.name] = proc
            case let .right(com):
                commands.append(com)
            }
            runningSubstring = nextLine.1
        }

        guard let lexedEnd = Lex.end.run(runningSubstring) else {
            errors[lexedProcedure.1.startIndex..<runningSubstring.startIndex] = .basic("Expected 'end' to close procedure declaration")
            hasFatalError = true
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<lexedEnd.1.startIndex, token: SyntaxType(category: .keyword))

        return (Procedure(name: lexedName.0, commands: commands, procedures: subProcedures, parameters: parameters), eatNewlines(lexedEnd.1))
    }

    internal func controlFlow(substring: Substring) -> (Command, Substring)? {
        if let command = Lex.Commands.controlFlow.run(substring) {
            let commandTokenRange = substring.startIndex..<command.1.startIndex

            switch command.0 {
            case .stop:
                registerToken(range: commandTokenRange, token: command.0)
                return (Stop(), command.1)
            case .make:
                registerToken(range: commandTokenRange, token: command.0)
                var runningSubstring = eatWhitespace(command.1)
                guard let literal = Lex.stringLiteral.run(runningSubstring) else {
                    errors[substring.startIndex..<command.1.startIndex] = .basic("Expected string literal as a name afer 'make'")
                    hasFatalError = true
                    return nil
                }

                registerToken(range: runningSubstring.startIndex..<literal.1.startIndex, token: SyntaxType(category: .stringLiteral))
                runningSubstring = eatWhitespace(literal.1)

                if let value = value(substring: runningSubstring) {
                    return (Make(value: value.0, symbol: literal.0), value.1)
                }
                // deref
                if let parsedDeref =  Lex.Token.deref.run(runningSubstring) {
                    let range = runningSubstring.startIndex..<parsedDeref.1.startIndex
                    registerToken(range: range, token: parsedDeref.0)
                    return (Make(value: parsedDeref.0, symbol: literal.0), parsedDeref.1)
                }
                errors[command.1.startIndex..<literal.1.startIndex] = .basic("Expected value to assign to '\(literal.0)'")
                hasFatalError = true
                return nil
            case .repeat_:
                registerToken(range: commandTokenRange, token: command.0)
                var runningSubstring = eatWhitespace(command.1)
                guard let repitions = signExpression(substring: runningSubstring) else {
                    errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected a value for 'repeat'")
                    hasFatalError = true
                    return nil
                }
                runningSubstring = eatWhitespace(repitions.1)
                guard let block = block(substring: runningSubstring) else {
                    errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected a code block to repeat")
                    hasFatalError = true
                    return nil
                }
                return (Repeat(count: repitions.0, block: block.0), block.1)
            case .ife:
                registerToken(range: commandTokenRange, token: command.0)
                var runningSubstring = eatWhitespace(command.1)
                guard let lhs = expression(substring: runningSubstring) else {
                    errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected expression before comparison")
                    hasFatalError = true
                    return nil
                }
                runningSubstring = eatWhitespace(lhs.1)
                guard let comparison = ComparisonOperator.parser.run(runningSubstring) else {
                    errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected <, >, or =")
                    hasFatalError = true
                    return nil
                }
                registerToken(range: runningSubstring.startIndex..<comparison.1.startIndex, token: comparison.0)
                runningSubstring = eatWhitespace(comparison.1)
                guard let rhs = expression(substring: runningSubstring) else {
                    errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected expression after '\(comparison.0.rawValue)'")
                    hasFatalError = true
                    return nil
                }
                runningSubstring = eatWhitespace(rhs.1)
                guard let block = block(substring: runningSubstring) else {
                    errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected a block of code after if statement")
                    hasFatalError = true
                    return nil
                }
                runningSubstring = eatWhitespace(block.1)
                return (Conditional(lhs: lhs.0, comparison: comparison.0.additionOperator, rhs: rhs.0, block: block.0), runningSubstring)
            case .output:
                if let value = value(substring: eatWhitespace(command.1)) {
                    return (Output(value: value.0), value.1)
                }
            case let .procedureInvocation(name):
                var runningSubstring = eatWhitespace(command.1)

                // black list
                if LogoParser.nameBlackList.contains(name) {
                    return nil
                }

                var expressions: [Value] = []
                while let parsedValue = value(substring: runningSubstring) {
                    expressions.append(parsedValue.0)
                    runningSubstring = parsedValue.1
                }

                let invocation = ProcedureInvocation(name: name, parameters: expressions)
                registerToken(range: commandTokenRange, token: invocation)
                return (invocation, runningSubstring)
            }
        }
        return nil
    }

    /// Keywords and reserved functions that are not considered .user Procedure Invocations
    /// These will basically be control flow and turtle commands
    private static let nameBlackList = Set(["end", "repeat", "make", "ife", "stop", "output"] )

    internal func command(substring: Substring) -> (Command, Substring)? {
        let chompedString = eatWhitespace(substring)

        if let controlFlowCommand = controlFlow(substring: chompedString) {
            return controlFlowCommand
        }
        
        return nil
    }

    private func block(substring: Substring) -> (Block, Substring)? {
        var runningSubstring = substring
        guard let blockStart = Lex.blockStart.run(runningSubstring) else {
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<blockStart.1.startIndex, token: SyntaxType(category: .plain))
        runningSubstring = eatNewlines(blockStart.1)

        var commands: [Command] = []
        var procedures: [String: Procedure] = [:]
        while let nextLine = line(substring: runningSubstring) {
            switch nextLine.0 {
            case let .left(proc):
                procedures[proc.name] = proc
            case let .right(com):
                commands.append(com)
            }
            runningSubstring = eatNewlines(nextLine.1)
        }

        guard let blockEnd = Lex.blockEnd.run(runningSubstring) else {
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<blockEnd.1.startIndex, token: SyntaxType(category: .plain))
        runningSubstring = eatWhitespace(blockEnd.1)

        return (Block(commands: commands, procedures: procedures), runningSubstring)
    }

    // MARK: - Values
    
    internal func value(substring: Substring) -> (Value, Substring)? {
        if let (string, remainder) = stringLiteral(substring: substring) {
            return (Value.string(string), remainder)
        }
        if let (exp, remainder) = expression(substring: substring) {
            return (Value.expression(exp), remainder)
        }
        // procedure invocations _may_ return values
        // TODO: static analysis to determine if procedures may return?
        if let (command, remainder) = controlFlow(substring: substring), let inv = command as? ProcedureInvocation {
            return (Value.procedure(inv), remainder)
        }
        return nil
    }
    
    internal func stringLiteral(substring: Substring) -> (String, Substring)? {
        guard let (string, remainder) = Lex.stringLiteral.run(substring) else {
            return nil
        }
        registerToken(range: substring.startIndex..<remainder.startIndex, token: SyntaxType(category: .stringLiteral))
        return (string, remainder)
    }
    
    // MARK: - Expressions

    /// expression
    /// : multiplyingExpression (('+' | '-') multiplyingExpression)*
    /// ;
    internal func expression(substring: Substring) -> (Expression, Substring)? {
        var runningSubstring = substring
        
        guard let (lhsToken, candidateSubstring) = multiplyingExpression(substring: substring) else {
            return nil
        }
        runningSubstring = eatWhitespace(candidateSubstring)

        var rhss: [Expression.Rhs] = []

        while let (op, opss) = AdditionOperator.parser.run(runningSubstring)  {
            // save + - operation
            let opRange = runningSubstring.startIndex..<opss.startIndex
            registerToken(range: opRange, token: op)
            // eat whitespace
            runningSubstring = eatWhitespace(opss)
            guard let (mE, mEss) = multiplyingExpression(substring: runningSubstring) else {
                errors[opRange] = .basic("Expected expression after '\(op.rawValue)'")
                hasFatalError = true
                return nil
            }
            runningSubstring = mEss
            rhss.append(Expression.Rhs(operation: op.additionOperator, rhs: mE))
        }

        if rhss.count == 0 {
            // don't eat whitespace if there are no proper operations found
            runningSubstring = candidateSubstring
        }

        return (Expression(lhs: lhsToken, rhs: rhss), runningSubstring)
    }

    /// multiplyingExpression
    /// : signExpression (('*' | '/') signExpression)*
    /// ;
    internal func multiplyingExpression(substring: Substring) -> (MultiplyingExpression, Substring)? {

        var runningSubstring = substring

        guard let (lhsToken, candidateSubstring) = signExpression(substring: substring) else {
            return nil
        }
        runningSubstring = eatWhitespace(candidateSubstring)

        var rhss: [MultiplyingExpression.Rhs] = []

        while let (op, opss) = MultiplicationOperator.parser.run(runningSubstring)  {
            // save * / operation
            let opRange = runningSubstring.startIndex..<opss.startIndex
            registerToken(range: opRange, token: op)
            // eat whitespace
            runningSubstring = eatWhitespace(opss)
            guard let (sE, sEss) = signExpression(substring: runningSubstring) else {
                errors[opRange] = .basic("Expected expression after '\(op.rawValue)'")
                hasFatalError = true
                return nil
            }
            runningSubstring = sEss
            rhss.append(MultiplyingExpression.Rhs(operation: op.multiplyingOperator, rhs: sE))
        }

        if rhss.count == 0 {
            // don't eat whitespace if there are no proper operations found
            runningSubstring = candidateSubstring
        }

        return (MultiplyingExpression(lhs: lhsToken, rhs: rhss), runningSubstring)
    }

    /// signExpression
    /// : (('+' | '-'))* (number | deref | func_)
    /// ;
    /// - Parameter substring: Program string from point of expected sign expression location
    /// - Returns: (location of sign expression, sign expression)
    internal func signExpression(substring: Substring) -> (SignExpression, Substring)? {

        var runningSubstring = substring

        runningSubstring = eatWhitespace(runningSubstring)
        // number
        if let parsedNumber =  Lex.Token.number.run(runningSubstring) {
            let range = runningSubstring.startIndex..<parsedNumber.1.startIndex
            registerToken(range: range, token: parsedNumber.0)
            return (SignExpression(sign: .positive, value: parsedNumber.0), parsedNumber.1)
        }

        let signParser = ({ _ in SignExpression.Sign.positive } <^> "+")
            <|> ({ _ in SignExpression.Sign.negative } <^> "-")

        let sign: SignExpression.Sign
        if let parsedSign = signParser.run(substring) {
            registerToken(range: substring.startIndex..<parsedSign.1.startIndex, token: SyntaxType(category: .operation))
            runningSubstring = parsedSign.1
            sign = parsedSign.0
        } else {
            sign = .positive
        }

        runningSubstring = eatWhitespace(runningSubstring)

        // deref
        if let parsedDeref =  Lex.Token.deref.run(runningSubstring) {
            let range = runningSubstring.startIndex..<parsedDeref.1.startIndex
            registerToken(range: range, token: parsedDeref.0)
            return (SignExpression(sign: sign, value: parsedDeref.0), parsedDeref.1)
        }

        return nil
    }

    // MARK: - Eat Utilities

    private func eatComment(_ substring: Substring) -> Substring {
        let runningSubstring = eatWhitespace(substring)
        if let comment = Lex.comment.run(runningSubstring) {
            registerToken(range: runningSubstring.startIndex..<comment.1.startIndex, token: SyntaxType(category: .comment))
            return comment.1
        }
        return substring
    }

    private func eatWhitespace(_ substring: Substring) -> Substring {
        if let (_, candidateSubstring) =  Lex.Token._w.run(substring) {
            return candidateSubstring
        }
        return substring
    }

    private func eatNewlines(_ substring: Substring) -> Substring {
        if let (_, candidateSubstring) =  Lex.Token.eol.run(substring) {
            return candidateSubstring
        }
        return substring
    }

}

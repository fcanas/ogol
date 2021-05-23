//
//  Parser.swift
//  OgoLang
//
//  Created by Fabián Cañas on 3/7/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Execution
import FFCParserCombinator
import Foundation
import ToolingSupport

enum Either<A, B>{
    case left(A)
    case right(B)
}

public class OgolParser: LanguageParser {

    // MARK: - Types

    public init() {}
    
    public var modules: [Module] = []
    public var additionalProcedures: [String:Procedure] = [:]
    
    public var commentDelimiter: String {
        get {
            Lex.commentDelimiter
        }
    }

    public func program(substring: Substring) -> ParseResult {

        hasFatalError = false
        errors = [:]
        allTokens = [:]

        var runningSubstring = eatNewlines(substring)
        var executionNodes: [ProcedureInvocation] = []
        var procedures: [Procedure] = []
        while let parsedLine = line(substring: runningSubstring) {
            switch parsedLine.0 {
            case let .left(p):
                procedures.append(p)
            case let .right(x):
                executionNodes.append(x)
            }
            runningSubstring = eatNewlines(parsedLine.1)
        }

        if hasFatalError {
            return .error(self.errors)
        }
        let program = Program(executionNodes: executionNodes, procedures: procedures)
        verifyProcedureCalls(for: program, modules: modules, procedures: additionalProcedures)

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

    func verifyProcedureCalls(for program: Program, modules: [Module], procedures: [String:Procedure] = [:]) {
        
        var procedures: [String:Procedure] = procedures.merging(program.procedures, uniquingKeysWith: { (a, b) in return a }) 
        
        for module in modules {
            procedures.merge(module.procedures) { (a, b) -> Procedure in
                return a
            }
        }
        
        allTokens.forEach { (range: Range<Substring.Index>, value: SyntaxColorable) in
            switch value.syntaxCategory() {
            case .procedureInvocation:
                guard let invocation = value as? ProcedureInvocation else {
                    break
                }

                let procedureName = invocation.name
                
                if let procedure = procedures[procedureName] {
                    let invocationCount = invocation.parameters.count
                    let declarationCount = procedure.parameters.count
                    if !procedure.invocationValidWith(parameterCount: invocationCount) {
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
    
    /// Keywords and reserved functions that are not considered .user Procedure Invocations
    /// These will basically be control flow
    private static let nameBlackList = Set(["end", "to"] )

    private func line(substring: Substring) -> (Either<Procedure, ProcedureInvocation>, Substring)? {
        var previous: Substring
        var skipCommentLine = substring
        repeat {
            previous = skipCommentLine
            skipCommentLine = eatComment(skipCommentLine)
        } while (previous != skipCommentLine)
        skipCommentLine = eatWhitespace(skipCommentLine)

        if let procedure = procedureDeclaration(substring: skipCommentLine) {
            return (Either.left(procedure.0), procedure.1)
        }
        if let command = procedureInvocation(substring: skipCommentLine) {
            let runningSubstring = eatNewlines(eatComment(command.1))
            return (Either.right(command.0), runningSubstring)
        }
        return nil
    }

    internal func procedureDeclaration(substring: Substring) -> (Procedure, Substring)? {
        var runningSubstring = substring
        guard let lexedProcedure = Lex.to.run(runningSubstring) else {
            // No procedure found. Ok.
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<lexedProcedure.1.startIndex, token: SyntaxType(category: .keyword))
        runningSubstring = eatWhitespace(lexedProcedure.1)
        guard let lexedName = Lex.name.run(runningSubstring) else {
            errors[substring.startIndex..<runningSubstring.startIndex] = .basic("Expected name following `to` defining a procedure")
            hasFatalError = true
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<lexedName.1.startIndex, token: SyntaxType(category: .procedureDefinition))
        runningSubstring = lexedName.1

        // Required inputs
        
        let parameterTokenizer = { (value: Value) -> Value in
            switch value {
            case .reference(_):
                break
            default:
                self.errors[substring.startIndex..<runningSubstring.startIndex] = .severeInternal("Parameter names must be declared as a reference")
                self.hasFatalError = true
            }
            return value
        } <^> Lex.Token.reference
        
        // [
        runningSubstring = eatWhitespace(runningSubstring)
        guard let (_, paramStartRemainder) = Lex.listStart.run(runningSubstring) else {
            self.errors[substring.startIndex..<runningSubstring.startIndex] = .basic("Expected a parameter list beginning with `[` following procedure declaration \(lexedName)")
            self.hasFatalError = true
            return nil
        }
        runningSubstring = eatWhitespace(paramStartRemainder)

        var parameters: [Value] = []
        if let param = parameterTokenizer.run(runningSubstring) {
            registerToken(range: runningSubstring.startIndex..<param.1.startIndex, token: SyntaxType(category: .parameterDeclaration))
            parameters.append(param.0)
            runningSubstring = param.1
            while let nextParam = (Lex.paramaterSeparator *> parameterTokenizer).run(runningSubstring) {
                registerToken(range: runningSubstring.startIndex..<nextParam.1.startIndex, token: SyntaxType(category: .parameterDeclaration))
                parameters.append(nextParam.0)
                runningSubstring = nextParam.1
            }
        }
        
        // Rest Input
        
        var hasRest = false
        let restTokenizer: Parser<Substring, Value>
        if parameters.count > 0 {
            restTokenizer = (Lex.paramaterSeparator *> Lex.listStart *> parameterTokenizer <* Lex.listEnd)
        } else {
            restTokenizer = (Lex.listStart *> parameterTokenizer <* Lex.listEnd)
        }
        if let param = restTokenizer.run(runningSubstring) {
            registerToken(range: runningSubstring.startIndex..<param.1.startIndex, token: SyntaxType(category: .parameterDeclaration))
            parameters.append(param.0)
            runningSubstring = param.1
            hasRest = true
        }
        
        // ]
        runningSubstring = eatWhitespace(runningSubstring)
        guard let (_, paramEndRemainder) = Lex.listEnd.run(runningSubstring) else {
            self.errors[substring.startIndex..<runningSubstring.startIndex] = .basic("Expected `]` for procedure declaration \(lexedName)")
            self.hasFatalError = true
            return nil
        }
        runningSubstring = paramEndRemainder
        runningSubstring = eatWhitespace(runningSubstring)
        
        // ^ End Procedure Definition Header.
        // -
        // v Begin Procedure Body

        runningSubstring = eatNewlines(runningSubstring)

        var commands: [ProcedureInvocation] = []
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
            errors[lexedProcedure.1.startIndex..<runningSubstring.startIndex] = .basic("Expected 'end' to close procedure declaration \(lexedName)")
            hasFatalError = true
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<lexedEnd.1.startIndex, token: SyntaxType(category: .keyword))

        return (.native(NativeProcedure(name: lexedName.0, commands: commands, procedures: subProcedures, parameters: parameters, hasRest: hasRest)), eatNewlines(lexedEnd.1))
    }

    internal func procedureInvocation(substring: Substring) -> (ProcedureInvocation, Substring)? {
        if let command = Lex.name.run(substring) {
            let commandTokenRange = substring.startIndex..<command.1.startIndex

            let name = command.0
            // [
            guard var (_, runningSubstring) = Lex.listStart.run(eatWhitespace(command.1)) else {
                return nil
            }
            runningSubstring = eatWhitespace(runningSubstring)
            
            // black list
            if OgolParser.nameBlackList.contains(name) {
                return nil
            }
            
            var expressions: [Value] = []
            while let parsedValue = value(substring: runningSubstring) {
                expressions.append(parsedValue.0)
                runningSubstring = parsedValue.1
                let separator = Lex.paramaterSeparator.run(runningSubstring)
                if separator?.1 == nil {
                    runningSubstring = eatWhitespace(runningSubstring)
                    break
                }
                runningSubstring = separator!.1
            }
            
            // ]
            runningSubstring = eatWhitespace(runningSubstring)
            guard let (_, endParams) = Lex.listEnd.run(runningSubstring) else {
                return nil
            }
            runningSubstring = eatWhitespace(endParams)
            
            
            let invocation = ProcedureInvocation(name: name, parameters: expressions)
            registerToken(range: commandTokenRange, token: invocation)
            return (invocation, runningSubstring)
        }
        return nil
    }
    
    private func instructionList(substring: Substring) -> (Value, Substring)? {
        var runningSubstring = substring
        guard let listStart = Lex.listStart.run(runningSubstring) else {
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<listStart.1.startIndex, token: SyntaxType(category: .plain))
        runningSubstring = eatNewlines(listStart.1)

        var commands: [ProcedureInvocation] = []
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

        guard let listEnd = Lex.listEnd.run(runningSubstring) else {
            return nil
        }
        registerToken(range: runningSubstring.startIndex..<listEnd.1.startIndex, token: SyntaxType(category: .plain))
        runningSubstring = eatWhitespace(listEnd.1)

        let commandListValue = commands.map { (executionNode) -> Bottom in
            return .command(executionNode)
        }
        
        return (.bottom(.list(commandListValue)), runningSubstring)
    }
    

    // MARK: - Values
    
    internal func value(substring: Substring) -> (Value, Substring)? {
        if let (string, remainder) = stringLiteral(substring: substring) {
            return (Value.bottom(.string(string)), remainder)
        }
        
        // procedure invocations _may_ return values
        // TODO: static analysis to determine if procedures may return?
        // Probably not strictly possible if lists are executable
        if let (command, remainder) = procedureInvocation(substring: substring) {
            return (Value.bottom(.command(command)), remainder)
        }
        
        if let (exp, remainder) = expression(substring: substring) {
            return (Value.expression(exp), remainder)
        }
        
        if let (ref, remainder) = reference(substring: substring) {
            return (ref, remainder)
        }
        
        return instructionList(substring: substring)
    }
    
    internal func stringLiteral(substring: Substring) -> (String, Substring)? {
        guard let (string, remainder) = Lex.stringLiteral.run(substring) else {
            return nil
        }
        registerToken(range: substring.startIndex..<remainder.startIndex, token: SyntaxType(category: .stringLiteral))
        return (string, remainder)
    }
    
    internal func reference(substring: Substring) -> (Value, Substring)? {
        guard let (string, remainder) = Lex.Token.reference.run(substring) else {
            return nil
        }
        registerToken(range: substring.startIndex..<remainder.startIndex, token: SyntaxType(category: .parameterDeclaration))
        return (string, remainder)
    }
    
    // MARK: - Expressions
    
    /// expression
    /// : arithmeticExpression (('<'|'>'|'=') arithmeticExpression)
    /// ;
    internal func expression(substring: Substring) -> (Expression, Substring)? {
        
        var runningSubstring = eatWhitespace(substring)
        
        guard let lhs = arithmeticExpression(substring: runningSubstring) else {
            //errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected expression before comparison")
            //hasFatalError = true
            return nil
        }
        runningSubstring = eatWhitespace(lhs.1)
        guard let comparison = ComparisonOperator.parser.run(runningSubstring) else {
            //errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected <, >, or =")
            //hasFatalError = true
            return (Expression(lhs: lhs.0, rhs: nil), lhs.1)
        }
        registerToken(range: runningSubstring.startIndex..<comparison.1.startIndex, token: comparison.0)
        runningSubstring = eatWhitespace(comparison.1)
        guard let rhs = arithmeticExpression(substring: runningSubstring) else {
            errors[substring.startIndex..<runningSubstring.startIndex] = ParseError.basic("Expected expression after '\(comparison.0.rawValue)'")
            hasFatalError = true
            return nil
        }
        
        return (Expression(lhs: lhs.0, rhs: Expression.Rhs(operation: comparison.0.comparisonOperator, rhs: rhs.0)), rhs.1)
    }
    
    /// arithmeticExpression
    /// : multiplyingExpression (('+' | '-') multiplyingExpression)*
    /// ;
    internal func arithmeticExpression(substring: Substring) -> (ArithmeticExpression, Substring)? {
        var runningSubstring = substring
        
        guard let (lhsToken, candidateSubstring) = multiplyingExpression(substring: substring) else {
            return nil
        }
        runningSubstring = eatWhitespace(candidateSubstring)

        var rhss: [ArithmeticExpression.Rhs] = []

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
            rhss.append(ArithmeticExpression.Rhs(operation: op.additionOperator, rhs: mE))
        }

        if rhss.count == 0 {
            // don't eat whitespace if there are no proper operations found
            runningSubstring = candidateSubstring
        }

        return (ArithmeticExpression(lhs: lhsToken, rhs: rhss), runningSubstring)
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
            return (SignExpression.positive(parsedNumber.0), parsedNumber.1)
        }

        enum PartialSign {
            case positive
            case negative
        }
        
        let signParser = ({ _ in PartialSign.positive } <^> "+")
            <|> ({ _ in PartialSign.negative } <^> "-")

        let sign: PartialSign
        if let parsedSign = signParser.run(substring) {
            registerToken(range: substring.startIndex..<parsedSign.1.startIndex, token: SyntaxType(category: .operation))
            runningSubstring = parsedSign.1
            sign = parsedSign.0
        } else {
            sign = .positive
        }

        runningSubstring = eatWhitespace(runningSubstring)

        // deref
        if let parsedDeref =  Lex.Token.lookup.run(runningSubstring) {
            let range = runningSubstring.startIndex..<parsedDeref.1.startIndex
            registerToken(range: range, token: parsedDeref.0)
            
            switch sign {
            case .positive:
                return (SignExpression.positive(parsedDeref.0), parsedDeref.1)
            case .negative:
                return (SignExpression.negative(parsedDeref.0), parsedDeref.1)
            }
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
        var s: Substring = substring
        while true {
            if let (_, candidateSubstring) =  Lex.Token.eol.run(s) {
                if s == candidateSubstring { return s }
                s = candidateSubstring
            } else {
                return s
            }
        }
    }
}

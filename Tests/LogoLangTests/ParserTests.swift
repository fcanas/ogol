//
//  ParserTests.swift
//  LogoLangTests
//
//  Created by Fabián Cañas on 4/5/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import XCTest
@testable import LogoLang

class SimpleCommandParserTests: XCTestCase {

    func testCs() throws {
        try _test("cs")
    }

    func testPu() throws {
        try _test("pu")
    }

    func testPd() throws {
        try _test("pd")
    }

    func testHt() throws {
        try _test("ht")
    }

    func testSt() throws {
        try _test("st")
    }

    func testHome() throws {
        try _test("home")
    }

    func _test(_ command: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let parser = LogoParser()
        let programString: Substring = Substring(command)
        guard let (_, s) = parser.command(substring: programString) else {
            XCTFail("Failed to parse basic command \(command)", file: file, line: line)
            return
        }
        guard let tokenKey = parser.allTokens.keys.first else {
            XCTFail("No token for basic command \(command)", file: file, line: line)
            return
        }
//        XCTAssertEqual(c as? ProcedureInvocation, ProcedureInvocation(identifier: .turtle(TurtleCommand.Partial(rawValue: command)!), parameters: []), file: file, line: line)
        XCTAssertEqual(programString[tokenKey], programString, file: file, line: line)
        XCTAssertEqual(s, "", file: file, line: line)
    }
    
    func testStop() {
        let parser = LogoParser()
        parser.modules = [Meta()]
        let programString: Substring = Substring("stop")
        guard let (c, s) = parser.command(substring: programString) else {
            XCTFail("Failed to parse stop")
            return
        }
        guard let tokenKey = parser.allTokens.keys.first else {
            XCTFail("No token for stop")
            return
        }
        guard case .invocation(_) = c else {
            XCTFail("Should parse a stop")
            return
        }
        XCTAssertEqual(programString[tokenKey], programString)
        XCTAssertEqual(s, "")
    }
    
    func testBasicCommand() {
        let parser = LogoParser()
        let programString: Substring = "fd 5\n"
        guard let (i, _) = parser.command(substring: programString) else {
            XCTFail("Failed to parse fd")
            return
        }
        let exp = Expression(lhs: MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(5)))))
        guard case let .invocation(inv) = i else {
            XCTFail("Should parse a stop")
            return
        }
        XCTAssertEqual(inv, ProcedureInvocation(name: "fd", parameters:[.expression(exp)]))
    }
    
    func testBasicCommandAlternateName() {
        let parser = LogoParser()
        let programString: Substring = "forward 5\n"
        guard let (i, _) = parser.command(substring: programString) else {
            XCTFail("Failed to parse fd")
            return
        }
        let exp = Expression(lhs: MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(5)))))

        guard case let .invocation(inv) = i else {
            XCTFail("Should parse an invocation")
            return
        }
        
        XCTAssertEqual(inv, ProcedureInvocation(name: "forward", parameters:[.expression(exp)]))
    }
    
    func testBasicInvocation() {
    	let parser = LogoParser()
    	let programString: Substring = "par 5\n"
    	guard let (i, _) = parser.command(substring: programString) else {
    		XCTFail("Failed to parse invocation")
    		return
    	}
        let exp = Expression(lhs: MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(5)))))

        guard case let .invocation(inv) = i else {
            XCTFail("Should parse an invocation")
            return
        }
        
        XCTAssertEqual(inv, ProcedureInvocation(name: "par", parameters:[.expression(exp)]))
    }
    
    func testInvocationPrefixedWithBuiltin() {
    	let parser = LogoParser()
    	let programString: Substring = "star 5\n"
    	guard let (i, _) = parser.command(substring: programString) else {
    		XCTFail("Failed to parse invocation")
    		return
    	}
        let exp = Expression(lhs: MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(5)))))

        guard case let .invocation(inv) = i else {
            XCTFail("Should parse an invocation")
            return
        }
        
        XCTAssertEqual(inv, ProcedureInvocation(name:"star", parameters:[.expression(exp)]))
    }

}

class SignExpressionParserTests: XCTestCase {

    func testNumbers() {
        _testSignExpression("-4", SignExpression.positive(.bottom(.double(-4))), ["-4"])
        _testSignExpression("1234", SignExpression.positive(.bottom(.double(1234))), ["1234"])
        _testSignExpression("54321", SignExpression.positive(.bottom(.double(54321))), ["54321"])
        _testSignExpression("-3.14", SignExpression.positive(.bottom(.double(-3.14))), ["-3.14"])
    }

    func testDeref() {
        _testSignExpression("-:symbol ", SignExpression.negative(.deref("symbol")), ["-", ":symbol"])
        _testSignExpression("- :symbol ", SignExpression.negative(.deref("symbol")), ["-", ":symbol"])
        _testSignExpression("-:Symbol ", SignExpression.negative(.deref("Symbol")), ["-", ":Symbol"])
        _testSignExpression(":Cymbal ", SignExpression.positive(.deref("Cymbal")), [":Cymbal"])
        _testSignExpression("+:Cymbal ", SignExpression.positive(.deref("Cymbal")), ["+", ":Cymbal"])
        _testSignExpression("+ :Cymbal7", SignExpression.positive(.deref("Cymbal7")), ["+", ":Cymbal7"])
    }

    func testRemainer() {
        let parser = LogoParser()
        guard let (_, remainder) = parser.signExpression(substring: "- :derefSymbol / 12") else {
            XCTFail("Failed to parse deref sign expression")
            return
        }
        XCTAssertEqual(remainder, " / 12")
    }

    func _testSignExpression(_ programString: Substring, _ expression: SignExpression, _ tokens: Array<Substring>, file: StaticString = #filePath, line: UInt = #line) {
        let parser = LogoParser()
        guard let (s, _) = parser.signExpression(substring: programString) else {
            XCTFail("Failed to parse sign expression", file: file, line: line)
            return
        }
        XCTAssertEqual(s, expression, file: file, line: line)

        let sortedKeys = parser.allTokens.keys.sorted(by: { $0.lowerBound < $1.lowerBound })
        for comparisonPair in zip(sortedKeys, tokens) {
            XCTAssertEqual(programString[comparisonPair.0], comparisonPair.1, file: file, line: line)
        }
    }
}

class MultiplyingExpressionParserTests: XCTestCase {

    func testLHS() {
        let parser = LogoParser()
        guard let (e, s) = parser.multiplyingExpression(substring: "12.345 p") else {
            XCTFail("Failed to parse LHS of Multiplying Expression")
            return
        }
        XCTAssertEqual(MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(12.345)))), e)
        XCTAssertEqual(s, " p", "A multiplying expression with no RHS shoud not eat remaining whitespace or tokens")
    }

    func testBasicMultiplication() {
        let parser = LogoParser()
        guard let (e, s) = parser.multiplyingExpression(substring: "-12 * 2") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = SignExpression.positive(.bottom(.double(-12)))
        let rhs = SignExpression.positive(.bottom(.double(2)))
        XCTAssertEqual(MultiplyingExpression(lhs: lhs, rhs: MultiplyingExpression.Rhs(operation: .multiply, rhs: rhs)), e)
        XCTAssertEqual(s, "")
    }

    func testBasicDivision() {
        let parser = LogoParser()
        guard let (e, s) = parser.multiplyingExpression(substring: "14.2 / -288.1") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = SignExpression.positive(.bottom(.double(14.2)))
        let rhs = SignExpression.positive(.bottom(.double(-288.1)))
        XCTAssertEqual(MultiplyingExpression(lhs: lhs, rhs: MultiplyingExpression.Rhs(operation: .divide, rhs: rhs)), e)
        XCTAssertEqual(s, "")
    }

    func testPrefixNegation() {
        let parser = LogoParser()
        guard let (e, s) = parser.multiplyingExpression(substring: "-3") else {
            XCTFail("Failed to parse prefix negative number")
            return
        }
        XCTAssert(s.count == 0)
        let lhs = SignExpression.positive(.bottom(.double(-3)))
        XCTAssertEqual(MultiplyingExpression(lhs: lhs), e)
    }

    func testVariables() {
        let parser = LogoParser()

        guard let (e, s) = parser.multiplyingExpression(substring: "-3 * :x") else {
            XCTFail("Failed to parse prefix negative number multiplied by a single-length vairable")
            return
        }

        XCTAssert(s.count == 0)
        let lhs = SignExpression.positive(.bottom(.double(-3)))
        let rhs = MultiplyingExpression.Rhs(operation: .multiply, rhs:SignExpression.positive(.deref("x")))
        XCTAssertEqual(e, MultiplyingExpression(lhs: lhs, rhs: rhs))
    }

    func testChaining() {
        let parser = LogoParser()
        guard let (e, s) = parser.multiplyingExpression(substring: "-3 / 1 *4 /1.5*-9 / 26 * -:x/+:y  x") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = SignExpression.positive(.bottom(.double(-3)))

        let rhs = [
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression.positive(.bottom(.double(1)))),
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression.positive(.bottom(.double(4)))),
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression.positive(.bottom(.double(1.5)))),
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression.positive(.bottom(.double(-9)))),
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression.positive(.bottom(.double(26)))),
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression.negative(.deref("x"))),
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression.positive(.deref("y")))
        ]
        XCTAssertEqual(MultiplyingExpression(lhs: lhs, rhs: rhs), e)
        XCTAssertEqual(s, "  x", "Chaining multiplying expressions should not eat whitespace")
    }

}

class ExpressionParserTests: XCTestCase {
    
    enum Sign {
        case positive
        case negative
    }

    func nestBasic(sign: Sign, value: Double) -> MultiplyingExpression {
        switch sign {
        case .positive:
            return MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(value))))
        case .negative:
            return MultiplyingExpression(lhs: SignExpression.negative(.bottom(.double(value))))
        }
    }

    func testLHS() {
        let parser = LogoParser()
        guard let (e, s) = parser.expression(substring: "12.345 p") else {
            XCTFail("Failed to parse LHS of Multiplying Expression")
            return
        }
        XCTAssertEqual(Expression(lhs: nestBasic(sign: .positive, value: 12.345)), e)
        XCTAssertEqual(s, " p", "An expression with no RHS shoud not eat remaining whitespace or tokens")
    }

    func testBasicAddition() {
        let parser = LogoParser()
        guard let (e, s) = parser.expression(substring: "-12 + 2 o") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = nestBasic(sign: .positive, value: -12)
        let rhs = nestBasic(sign: .positive, value: 2)
        XCTAssertEqual(Expression(lhs: lhs, rhs: Expression.Rhs(operation: .add, rhs: rhs)), e)
        XCTAssertEqual(s, " o")
    }

    func testBasicSubtraction() {
        let parser = LogoParser()
        guard let (e, s) = parser.expression(substring: "-12 - 42 x") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = nestBasic(sign: .positive, value: -12)
        let rhs = nestBasic(sign: .positive, value: 42)
        XCTAssertEqual(Expression(lhs: lhs, rhs: Expression.Rhs(operation: .subtract, rhs: rhs)), e)
        XCTAssertEqual(s, " x")
    }

    func testChaining() {
        let parser = LogoParser()
        guard let (e, s) = parser.expression(substring: "-3 + 1 *4 /1.5--9 / 26 * -:x++:y  z a p") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(-3))))


        let mRhs1 = [
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression.positive(.bottom(.double(4)))),
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression.positive(.bottom(.double(1.5))))
        ]
        let m1 = MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(1))), rhs: mRhs1)

        let mRhs2 = [
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression.positive(.bottom(.double(26)))),
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression.negative(.deref("x"))),
        ]
        let m2 = MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(-9))), rhs: mRhs2)

        let rhs: [Expression.Rhs] = [
            Expression.Rhs(operation: .add, rhs: m1),
            Expression.Rhs(operation: .subtract, rhs: m2),
            Expression.Rhs(operation: .add, rhs: MultiplyingExpression(lhs: SignExpression.positive(.deref("y"))))
        ]

        XCTAssertEqual(Expression(lhs: lhs, rhs: rhs), e)
        XCTAssertEqual(s, "  z a p", "Chaining expressions should not eat whitespace")
    }

}

class ProcedureDeclarationTests: XCTestCase {
    func testBasicDefinition() {
        let parser = LogoParser()
        guard case let .success(p, _, _) = parser.program(substring: """
            to doodle
            end
            """
        ) else {
            XCTFail("Failed to parse basic procedure declaration")
            return
        }
        XCTAssertEqual(p.procedures.count, 1)
        XCTAssertNotNil(p.procedures["doodle"])
    }
    
    func testSingleParameter() {
        let parser = LogoParser()
        guard case let .success(p, _, _) = parser.program(substring: """
            to doodle :foo
            end
            """
        ) else {
            XCTFail("Failed to parse basic procedure declaration with single parameter")
            return
        }
        XCTAssertEqual(p.procedures.count, 1)
        let doodle = p.procedures["doodle"]!
        XCTAssertNotNil(doodle)
        
        XCTAssertEqual(doodle.parameters, ["foo"])
    }
    
    func testMultipleParameters() {
        let parser = LogoParser()
        guard case let .success(p, _, _) = parser.program(substring: """
            to doodle :foo, :bar, :baz, :alice, :bob, :carol, :ted
            end
            """
        ) else {
            XCTFail("Failed to parse basic procedure declaration with multiple parameters")
            return
        }
        XCTAssertEqual(p.procedures.count, 1)
        let doodle = p.procedures["doodle"]!
        XCTAssertNotNil(doodle)
        
        XCTAssertEqual(doodle.parameters, ["foo", "bar", "baz", "alice", "bob", "carol", "ted"])
    }
    
    func testTrailingRestParameter() {
        let parser = LogoParser()
        guard case let .success(p, _, _) = parser.program(substring: """
            to doodle :foo, :bar, [:baz]
            end
            """
        ) else {
            XCTFail("Failed to parse basic procedure declaration")
            return
        }
        XCTAssertEqual(p.procedures.count, 1)
        let doodle = p.procedures["doodle"]!
        XCTAssertNotNil(doodle)
        
        XCTAssertEqual(doodle.parameters, ["foo", "bar", "baz"])
    }
    
    func testRestParameter() {
        let parser = LogoParser()
        guard case let .success(p, _, _) = parser.program(substring: """
            to doodle [:doo]
            end
            """
        ) else {
            XCTFail("Failed to parse basic procedure declaration")
            return
        }
        XCTAssertEqual(p.procedures.count, 1)
        let doodle = p.procedures["doodle"]!
        XCTAssertNotNil(doodle)
        
        XCTAssertEqual(doodle.parameters, ["doo"])
    }
    
    func testRestParameterMustBeLast() {
        let parser = LogoParser()
        guard case .success(_, _, _) = parser.program(substring: """
            to doodle :foo, [:doo], :wah
            end
            """
        ) else {
            return
        }
        XCTFail("Failed to parse basic procedure declaration")
    }
    
    func testSingleRestParameter() {
        let parser = LogoParser()
        guard case .success(_, _, _) = parser.program(substring: """
            to doodle :[foo], [:doo]
            end
            """
        ) else {
            return
        }
        XCTFail("Failed to parse basic procedure declaration")
    }
}

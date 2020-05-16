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

    func _test(_ command: String, file: StaticString = #file, line: UInt = #line) throws {
        let parser = LogoParser()
        let programString: Substring = Substring(command)
        guard let (c, s) = parser.command(substring: programString) else {
            XCTFail("Failed to parse basic command \(command)", file: file, line: line)
            return
        }
        guard let tokenKey = parser.allTokens.keys.first else {
            XCTFail("No token for basic command \(command)", file: file, line: line)
            return
        }
        XCTAssertEqual(c as? ProcedureInvocation, ProcedureInvocation(identifier: .turtle(TurtleCommand.Partial(rawValue: command)!), parameters: []), file: file, line: line)
        XCTAssertEqual(programString[tokenKey], programString, file: file, line: line)
        XCTAssertEqual(s, "", file: file, line: line)
    }
    
    func testStop() {
        let parser = LogoParser()
        let programString: Substring = Substring("stop")
        guard let (c, s) = parser.command(substring: programString) else {
            XCTFail("Failed to parse stop")
            return
        }
        guard let tokenKey = parser.allTokens.keys.first else {
            XCTFail("No token for stop")
            return
        }
        XCTAssertNotNil(c as? Stop)
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
        let exp = Expression(lhs: MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .number(5))))

        XCTAssertEqual(i as? ProcedureInvocation, ProcedureInvocation(identifier: .turtle(.fd), parameters:[.expression(exp)]))
    }
    
    func testBasicCommandAlternateName() {
        let parser = LogoParser()
        let programString: Substring = "forward 5\n"
        guard let (i, _) = parser.command(substring: programString) else {
            XCTFail("Failed to parse fd")
            return
        }
        let exp = Expression(lhs: MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .number(5))))

        XCTAssertEqual(i as? ProcedureInvocation, ProcedureInvocation(identifier: .turtle(.fd), parameters:[.expression(exp)]))
    }
    
    func testBasicInvocation() {
    	let parser = LogoParser()
    	let programString: Substring = "par 5\n"
    	guard let (i, _) = parser.command(substring: programString) else {
    		XCTFail("Failed to parse invocation")
    		return
    	}
		let exp = Expression(lhs: MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .number(5))))

        XCTAssertEqual(i as? ProcedureInvocation, ProcedureInvocation(identifier: .user("par"), parameters:[.expression(exp)]))
    }
    
    func testInvocationPrefixedWithBuiltin() {
    	let parser = LogoParser()
    	let programString: Substring = "star 5\n"
    	guard let (i, _) = parser.command(substring: programString) else {
    		XCTFail("Failed to parse invocation")
    		return
    	}
		let exp = Expression(lhs: MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .number(5))))

        XCTAssertEqual(i as? ProcedureInvocation, ProcedureInvocation(identifier: .user("star"), parameters:[.expression(exp)]))
    }

}

class SignExpressionParserTests: XCTestCase {

    func testNumbers() {
        _testSignExpression("-4", SignExpression(sign: .positive, value: .number(-4)), ["-4"])
        _testSignExpression("1234", SignExpression(sign: .positive, value: .number(1234)), ["1234"])
        _testSignExpression("54321", SignExpression(sign: .positive, value: .number(54321)), ["54321"])
        _testSignExpression("-3.14", SignExpression(sign: .positive, value: .number(-3.14)), ["-3.14"])
    }

    func testDeref() {
        _testSignExpression("-:symbol ", SignExpression(sign: .negative, value: .deref("symbol")), ["-", ":symbol"])
        _testSignExpression("- :symbol ", SignExpression(sign: .negative, value: .deref("symbol")), ["-", ":symbol"])
        _testSignExpression("-:Symbol ", SignExpression(sign: .negative, value: .deref("Symbol")), ["-", ":Symbol"])
        _testSignExpression(":Cymbal ", SignExpression(sign: .positive, value: .deref("Cymbal")), [":Cymbal"])
        _testSignExpression("+:Cymbal ", SignExpression(sign: .positive, value: .deref("Cymbal")), ["+", ":Cymbal"])
        _testSignExpression("+ :Cymbal7", SignExpression(sign: .positive, value: .deref("Cymbal7")), ["+", ":Cymbal7"])
    }

    func testRemainer() {
        let parser = LogoParser()
        guard let (_, remainder) = parser.signExpression(substring: "- :derefSymbol / 12") else {
            XCTFail("Failed to parse deref sign expression")
            return
        }
        XCTAssertEqual(remainder, " / 12")
    }

    func _testSignExpression(_ programString: Substring, _ expression: SignExpression, _ tokens: Array<Substring>, file: StaticString = #file, line: UInt = #line) {
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
        XCTAssertEqual(MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .number(12.345))), e)
        XCTAssertEqual(s, " p", "A multiplying expression with no RHS shoud not eat remaining whitespace or tokens")
    }

    func testBasicMultiplication() {
        let parser = LogoParser()
        guard let (e, s) = parser.multiplyingExpression(substring: "-12 * 2") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = SignExpression(sign: .positive, value: .number(-12))
        let rhs = SignExpression(sign: .positive, value: .number(2))
        XCTAssertEqual(MultiplyingExpression(lhs: lhs, rhs: MultiplyingExpression.Rhs(operation: .multiply, rhs: rhs)), e)
        XCTAssertEqual(s, "")
    }

    func testBasicDivision() {
        let parser = LogoParser()
        guard let (e, s) = parser.multiplyingExpression(substring: "14.2 / -288.1") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = SignExpression(sign: .positive, value: .number(14.2))
        let rhs = SignExpression(sign: .positive, value: .number(-288.1))
        XCTAssertEqual(MultiplyingExpression(lhs: lhs, rhs: MultiplyingExpression.Rhs(operation: .divide, rhs: rhs)), e)
        XCTAssertEqual(s, "")
    }

    func testChaining() {
        let parser = LogoParser()
        guard let (e, s) = parser.multiplyingExpression(substring: "-3 / 1 *4 /1.5*-9 / 26 * -:x/+:y  x") else {
            XCTFail("Failed to parse Multiplying Expression")
            return
        }
        let lhs = SignExpression(sign: .positive, value: .number(-3))

        let rhs = [
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression(sign: .positive, value: .number(1))),
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression(sign: .positive, value: .number(4))),
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression(sign: .positive, value: .number(1.5))),
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression(sign: .positive, value: .number(-9))),
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression(sign: .positive, value: .number(26))),
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression(sign: .negative, value: .deref("x"))),
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression(sign: .positive, value: .deref("y"))),
        ]
        XCTAssertEqual(MultiplyingExpression(lhs: lhs, rhs: rhs), e)
        XCTAssertEqual(s, "  x", "Chaining multiplying expressions should not eat whitespace")
    }

}

class ExpressionParserTests: XCTestCase {

    func nestBasic(sign: SignExpression.Sign, value: Double) -> MultiplyingExpression {
        return MultiplyingExpression(lhs: SignExpression(sign: sign, value: .number(value)))
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
        let lhs = MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .number(-3)))


        let mRhs1 = [
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression(sign: .positive, value: .number(4))),
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression(sign: .positive, value: .number(1.5)))
        ]
        let m1 = MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .number(1)), rhs: mRhs1)

        let mRhs2 = [
            MultiplyingExpression.Rhs(operation: .divide, rhs: SignExpression(sign: .positive, value: .number(26))),
            MultiplyingExpression.Rhs(operation: .multiply, rhs: SignExpression(sign: .negative, value: .deref("x"))),
        ]
        let m2 = MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .number(-9)), rhs: mRhs2)

        let rhs: [Expression.Rhs] = [
            Expression.Rhs(operation: .add, rhs: m1),
            Expression.Rhs(operation: .subtract, rhs: m2),
            Expression.Rhs(operation: .add, rhs: MultiplyingExpression(lhs: SignExpression(sign: .positive, value: .deref("y"))))
        ]

        XCTAssertEqual(Expression(lhs: lhs, rhs: rhs), e)
        XCTAssertEqual(s, "  z a p", "Chaining expressions should not eat whitespace")
    }

}


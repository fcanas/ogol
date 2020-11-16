//
//  File.swift
//  
//
//  Created by Fabian Canas on 11/15/20.
//

import Execution
import libOgol
import XCTest

@testable import OgoLang

class ParserTests: XCTestCase {
    
    func testBasicInvocation() {
        let parser = OgolParser()
        let programString: Substring = "par [5]\n"
        guard let (inv, _) = parser.procedureInvocation(substring: programString) else {
            XCTFail("Failed to parse invocation")
            return
        }
        let exp = Expression(lhs:ArithmeticExpression(lhs: MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(5))))), rhs:nil)
        
        XCTAssertEqual(inv, ProcedureInvocation(name: "par", parameters:[.expression(exp)]))
    }
    
    func testProcedureInvocationAsParameter() {
        let parser = OgolParser()
        let programString: Substring = "proc [ subroutine [ 3 ] ]"
        guard let (inv, _) = parser.procedureInvocation(substring: programString) else {
            XCTFail("Failed to parse invocation")
            return
        }
        XCTAssertEqual(inv.name, "proc")
    }
    
    func testProcedureInvocationInExpressions() {
        let parser = OgolParser()
        let programString: Substring = "proc [ random [5] ]\n"
        guard let (inv, _) = parser.procedureInvocation(substring: programString) else {
            XCTFail("Failed to parse invocation")
            return
        }
        
        
        XCTAssertEqual(inv.name, "proc")
        guard case let .bottom(.command(procParameter)) = inv.parameters.first else {
            XCTFail("Failed to parse parameter")
            return
        }
        
        let exp = Expression(lhs:ArithmeticExpression(lhs: MultiplyingExpression(lhs: SignExpression.positive(.bottom(.double(5))))), rhs:nil)
        XCTAssertEqual(procParameter, ProcedureInvocation(name: "random", parameters:[.expression(exp)]))
    }
}

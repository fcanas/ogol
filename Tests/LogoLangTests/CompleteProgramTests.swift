//
//  CompleteProgramTests.swift
//  LogoLangTests
//
//  Created by Fabian Canas on 5/3/20.
//

@testable import LogoLang
import XCTest

class CompleteProgramTests: XCTestCase {

    func testProgramA() {
        let program =   """
                        make "diam  100
                        make "radius :diam / 2
                        make "cDivs 36 ; ought be be even
                        make "halfCircle :cDivs / 2
                        make "pi 22 / 7
                        make "cStep :pi * :diam / :cDivs
                        make "arcAngle 360 / :cDivs
                        
                        setxy 158 50
                        
                        to writeA
                            make "AAngle 20
                            make "crossLength 34
                            make "legLength 105
                            make "upperHalfLength 50
                            rt :AAngle
                            fd :legLength
                            rt 180 - 2 * :AAngle
                            fd :upperHalfLength
                            rt 90 + :AAngle
                            fd :crossLength
                            bk :crossLength
                            lt 90 + :AAngle
                            fd :legLength - :upperHalfLength
                            lt 90 - :AAngle
                            lt 90
                        end
                        
                        writeA
                        """
        let parser = LogoParser()
        let parseResult = parser.program(substring: Substring(program))
        
        switch parseResult {
        case .error(_):
            XCTFail("Failed to parse program")
        case let .success(program, _, parseError):
            XCTAssert(parseError.count == 0, "Program should not contain any parse errors")
            
            XCTAssertEqual(program.commands.count, 9, "This program should have 9 commands")
            XCTAssertEqual(program.procedures.count, 1, "This program should have 1 procedure")
            
            guard let procedureName = program.procedures.keys.first, let procedure = program.procedures[procedureName] else {
                XCTFail("Cannot complete testing without a procedure name")
                return
            }
            XCTAssertEqual(procedureName, "writeA", "Parsed procedure name does not match")
            XCTAssertEqual(procedure.commands.count, 15)
            XCTAssertEqual(procedure.procedures.count, 0)
            XCTAssertEqual(procedure.parameters.count, 0)
            
            // TODO: Syntax coloring
            // TODO: verify actual commands, or drawing output?
        }
        
        
        
    }

}

//
//  CompleteProgramTests.swift
//  LogoLangTests
//
//  Created by Fabian Canas on 5/3/20.
//

@testable import LogoLang
import libLogo
import XCTest

class CompleteProgramTests: XCTestCase {
    
    func testTreeDrawing() {
        let source = """
                      to tree :size
                          if :size < 5 [fd :size bk :size stop]
                          fd :size/3
                          lt 30 tree :size*2/3 rt 30
                          fd :size/6
                          rt 25 tree :size/2 lt 25
                          fd :size/3
                          rt 25 tree :size/2 lt 25
                          fd :size/6
                          bk :size
                      end
                      cs
                      optimize "tree
                      tree 720
                      """
        
        guard case let .success(program, _, _) = LogoParser().program(substring: Substring(source)) else {
            XCTFail("Failed to parse performance program")
            return
        }
        
        let context: ExecutionContext = ExecutionContext()
        context.load(Optimizer.self)
        context.load(Turtle.self)
        self.measure {
            try! program.execute(context: context, reuseScope: false)
        }
    }
    
    func testExpressionSimplification() {
        let source =    """
                        to keepbusy
                        repeat 7000 [
                            fd 100 * 10 * 20 / 20 + 200 + 8 + 11 * 8 + 1 + 3 + 7 * 5 / 3 / 100 * 10 * 20 / 20 + 200 + 8 + 11 * 8 + 1 + 3 + 7 * 5 / 3
                            bk 100 * 10 * 20 / 20 + 200 + 8 + 11 * 8 + 1 + 3 + 7 * 5 / 3 / 100 * 10 * 20 / 20 + 200 + 8 + 11 * 8 + 1 + 3 + 7 * 5 / 3
                        ]
                        end
                        optimize "keepbusy
                        keepbusy
                        """
        guard case let .success(program, _, _) = LogoParser().program(substring: Substring(source)) else {
            XCTFail("Failed to parse performance program")
            return
        }
        
        self.measure {
            let context: ExecutionContext = ExecutionContext()
            context.load(Optimizer.self)
            context.load(Turtle.self)
            try! program.execute(context: context, reuseScope: false)
        }
    }
    
    func testTailRecursion() {
        let source = """
                      to swirl :far
                          if :far < 0.01 [ stop ]
                          fd :far
                          rt 0.01
                          swirl :far * 0.99987
                      end
                      swirl 400
                      """
        
        guard case let .success(program, _, _) = LogoParser().program(substring: Substring(source)) else {
            XCTFail("Failed to parse performance program")
            return
        }
        
        // execute
        self.measure {
            let context: ExecutionContext = ExecutionContext()
            context.load(Turtle.self)
            try! program.execute(context: context, reuseScope: false)
        }
    }
    
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
            let fatalErrors = parseError.filter { (_, e) -> Bool in
                switch e {
                case .anticipatedRuntime(_):
                    return false
                default:
                    return true
                }
            }
            XCTAssert(fatalErrors.count == 0, "Program should not contain any parse errors")
            
            XCTAssertEqual(program.commands.count, 9, "This program should have 9 commands")
            XCTAssertEqual(program.procedures.count, 1, "This program should have 1 procedure")
            
            guard let procedureName = program.procedures.keys.first, case let .native(procedure) = program.procedures[procedureName] else {
                XCTFail("Cannot complete testing without a procedure name")
                return
            }
            XCTAssertEqual(procedureName, "writeA", "Parsed procedure name does not match")
            XCTAssertEqual(procedure.commands.count, 15)
            XCTAssertEqual(procedure.procedures.count, 0)
            XCTAssertEqual(procedure.parameters.count, 0)
            
            _ = try! SVGEncoder().encode(program: program)

            // print(svgOut)
            // XCTAssertEqual(svgOut,
            //               "<svg version=\"1.1\" baseProfile=\"full\" width=\"500\" height=\"500\" xmlns=\"http://www.w3.org/2000/svg\"><polyline fill=\"none\" stroke=\"black\" points=\"158.0, 130.0 122.08788495080478, 31.332274817479615 104.98687778452131, 78.31690585677502 138.9868777845213, 78.31690585677504 104.98687778452131, 78.31690585677502 86.1757699016095, 129.99999999999997\"/></svg>")
            
            // TODO: Syntax coloring
        }
    }
    
    func testLogoLogo() {
        let program =   """
                    make "diam  100
                    make "radius :diam / 2
                    make "cDivs 80; ought be be even
                    make "halfCircle :cDivs / 2
                    make "pi 22 / 7
                    make "cStep :pi * :diam / :cDivs
                    make "arcAngle 360 / :cDivs

                    to printL
                        rt 180 fd :diam lt 90 fd :diam * 0.60 lt 90 ; L
                    end
                    to printO
                        rt :arcAngle / 2
                        repeat :cDivs [ fd :cStep rt :arcAngle ]
                         lt :arcAngle / 2
                        rt 90
                    end
                    to printG
                        rt :arcAngle / 2
                        repeat :halfCircle [ fd :cStep rt :arcAngle ]
                        lt :arcAngle / 2
                        pu
                        rt 90 fd :radius lt 90 pd
                        fd :radius rt 90 fd :radius rt 180
                    end
                    to next :charSpace
                        pu
                        rt 90 fd :charSpace lt 90 lt 90 pd
                    end

                    make "nRadius -:radius
                    setxy 188 :nRadius
                     
                    printL

                    next :diam / 2 - 5

                    printO

                    next 110

                    printG

                    next 65

                    printO

                    pu
                    fd :radius
                    """
        let parser = LogoParser()
        let parseResult = parser.program(substring: Substring(program))
        
        switch parseResult {
        case .error(_):
            XCTFail("Failed to parse program")
        case let .success(program, _, parseError):
            let fatalErrors = parseError.filter { (_, e) -> Bool in
                switch e {
                case .anticipatedRuntime(_):
                    return false
                default:
                    return true
                }
            }
            XCTAssert(fatalErrors.count == 0, "Program should not contain any parse errors")
            
            XCTAssertEqual(program.commands.count, 18)
            XCTAssertEqual(program.procedures.count, 4)
            
            // TODO: Procedure content
            
            let context: ExecutionContext = ExecutionContext()
            context.load(Turtle.self)
            
            try! program.execute(context: context, reuseScope: false)

            let multiLines = Turtle.multilines(for: context)
            
            _ = try! SVGEncoder().encode(multiLines)

            //XCTAssertEqual(svgOut,
//                           "<svg version=\"1.1\" baseProfile=\"full\" width=\"500\" height=\"500\" xmlns=\"http://www.w3.org/2000/svg\"><polyline fill=\"none\" stroke=\"black\" points=\"158.0, 130.0 122.08788495080478, 31.332274817479615 104.98687778452131, 78.31690585677502 138.9868777845213, 78.31690585677504 104.98687778452131, 78.31690585677502 86.1757699016095, 129.99999999999997\"/></svg>")
            
            // TODO: Syntax coloring
        }
    }
    
    func testFlower() {
        let program =   """
                        make "turnAmount 10
                        make "stepPerTurn 20
                        make "counter 0

                        repeat 558 [
                            if :counter > 360 / 12 [
                                make "counter 0
                                lt :turnAmount * 5
                            ]
                            make "counter :counter + 1

                            repeat :turnAmount [
                                rt 1
                                fd :stepPerTurn / :turnAmount
                            ]
                        ]

                        ht
                        """
        let parser = LogoParser()
        let parseResult = parser.program(substring: Substring(program))
        
        switch parseResult {
        case .error(_):
            XCTFail("Failed to parse program")
        case let .success(program, _, parseError):
            let fatalErrors = parseError.filter { (_, e) -> Bool in
                switch e {
                case .anticipatedRuntime(_):
                    return false
                default:
                    return true
                }
            }
            XCTAssert(fatalErrors.count == 0, "Program should not contain any parse errors")
            
            XCTAssertEqual(program.commands.count, 5)
            XCTAssertEqual(program.procedures.count, 0)
            
            // TODO: Procedure content
            
            let context: ExecutionContext = ExecutionContext()
            context.load(Turtle.self)

            try! program.execute(context: context, reuseScope: false)

            let multiLines = Turtle.multilines(for: context)
            
            _ = try! SVGEncoder().encode(multiLines)
        }
        
    }
    
}

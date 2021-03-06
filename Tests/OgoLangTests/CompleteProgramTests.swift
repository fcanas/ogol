//
//  CompleteProgramTests.swift
//  LogoLangTests
//
//  Created by Fabian Canas on 5/3/20.
//

@testable import OgoLang
import libOgol
import Execution
import XCTest

func AssertMatchMultilineString( _ e1: @autoclosure () throws -> String, _ e2: @autoclosure () throws -> String, separator: String, file: StaticString = #file, line: UInt = #line) {

    do {
        let e1Components = try e1().components(separatedBy: separator)
        let e2Components = try e2().components(separatedBy: separator)

        let z = zip(e1Components, e2Components)

        var fileLine: Int = 0
        for (s1, s2) in z {
            fileLine += 1
            XCTAssertEqual(s1, s2, file: file, line: line)
        }

        XCTAssertEqual(e1Components.count, e2Components.count, "Expected \(e1Components.count) lines, but found \(e2Components.count) lines")

    } catch {
        XCTFail(file: file, line: line)
    }

}

class CompleteProgramTests: XCTestCase {
    
    func testTreeDrawing() {
        let source = """
                     to tree [:size]
                         if [size < 5, [
                         fd [size]
                         bk [size]
                         stop[]
                         ]]
                         fd [size/3]
                         lt [30]
                         tree [size*2/3]
                         rt [30]
                         fd [size/6]
                         rt [25]
                         tree [size/2]
                         lt [25]
                         fd [size/3]
                         rt [25]
                         tree [size/2]
                         lt [25]
                         fd [size/6]
                         bk [size]
                     end
                     cs[]
                     optimize[:tree]
                     tree [720]
                     """
        let parser = OgolParser()
        parser.modules = [Turtle(), Optimizer(), Meta()]
        
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse performance program")
            return
        }
        
        let context: ExecutionContext = ExecutionContext()
        context.load(Optimizer())
        context.load(Turtle())
        context.load(Meta())
        self.measure {
            try! program.execute(context: context, reuseScope: false)
        }
    }
    
    func testExpressionSimplification() {
        let source =    """
                        to keepbusy[]
                        repeat [7000, [
                            fd [100 * 10 * 20 / 20 + 200 + 8 + 11 * 8 + 1 + 3 + 7 * 5 / 3 / 100 * 10 * 20 / 20 + 200 + 8 + 11 * 8 + 1 + 3 + 7 * 5 / 3]
                            bk [100 * 10 * 20 / 20 + 200 + 8 + 11 * 8 + 1 + 3 + 7 * 5 / 3 / 100 * 10 * 20 / 20 + 200 + 8 + 11 * 8 + 1 + 3 + 7 * 5 / 3]
                        ]]
                        end
                        optimize [:keepbusy]
                        keepbusy[]
                        """
        let parser = OgolParser()
        parser.modules = [Turtle(), Optimizer()]
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse performance program")
            return
        }
        
        self.measure {
            let context: ExecutionContext = ExecutionContext()
            context.load(Optimizer())
            context.load(Turtle())
            context.load(Meta())
            do {
            try program.execute(context: context, reuseScope: false)
            } catch let e {
                print(e)
            }
        }
    }
    
    func testTailRecursion() {
        let source = """
                     to swirl [:far]
                       if [far < 0.01, [ stop[] ]]
                       fd [far]
                       rt [0.01]
                       swirl [far * 0.99987]
                     end
                     swirl [400]
                     """
        let parser = OgolParser()
        parser.modules = [Turtle(), Optimizer(), Meta()]
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse performance program")
            return
        }
        
        // execute
        self.measure {
            let context: ExecutionContext = ExecutionContext()
            context.load(Turtle())
            context.load(Meta())
            try! program.execute(context: context, reuseScope: false)
        }
    }
    
    func testProgramA() {
        let program =   """
                        make [:diam,  100]
                        make [:radius, diam / 2]
                        make [:cDivs, 36] ; ought be be even
                        make [:halfCircle, cDivs / 2]
                        make [:pi, 22 / 7]
                        make [:cStep, pi * diam / cDivs]
                        make [:arcAngle, 360 / cDivs]
                        
                        setxy [158, 50]
                        
                        to writeA[]
                            make [:AAngle, 20]
                            make [:crossLength, 34]
                            make [:legLength, 105]
                            make [:upperHalfLength, 50]
                            rt [AAngle]
                            fd [legLength]
                            rt [180 - 2 * AAngle]
                            fd [upperHalfLength]
                            rt [90 + AAngle]
                            fd [crossLength]
                            bk [crossLength]
                            lt [90 + AAngle]
                            fd [legLength - upperHalfLength]
                            lt [90 - AAngle]
                            lt [90]
                        end
                        
                        writeA[]
                        """
        let parser = OgolParser()
        parser.modules = [Turtle(), Meta()]
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
                    make [:diam,  100]
                    make [:radius, diam / 2]
                    make [:cDivs, 80] ; ought be be even
                    make [:halfCircle, cDivs / 2]
                    make [:pi, 22 / 7]
                    make [:cStep, pi * diam / cDivs]
                    make [:arcAngle, 360 / cDivs]

                    to printL[]
                        rt [180]
                        fd [diam]
                        lt [90]
                        fd [diam * 0.60]
                        lt [90]
                    end
                    to printO[]
                        rt [arcAngle / 2]
                        repeat [cDivs, [
                            fd [cStep]
                            rt [arcAngle]
                        ]]
                        lt [arcAngle / 2]
                        rt [90]
                    end
                    to printG[]
                        rt [arcAngle / 2]
                        repeat [halfCircle, [
                            fd [cStep]
                            rt [arcAngle]
                        ]]
                        lt [arcAngle / 2]
                        pu[]
                        rt [90]
                        fd [radius]
                        lt [90]
                        pd []
                        fd [radius]
                        rt [90]
                        fd [radius]
                        rt [180]
                    end
                    to next [:charSpace]
                        pu []
                        rt [90]
                        fd [charSpace]
                        lt [90]
                        lt [90]
                        pd []
                    end

                    make [:nRadius, -radius]
                    setxy [188, nRadius]
                     
                    printL[]

                    next [diam / 2 - 5]

                    printO []

                    next [110]

                    printG []

                    next [65]

                    printO []

                    pu []
                    fd [radius]
                    """
        let parser = OgolParser()
        parser.modules = [Turtle(), Meta()]
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
            context.load(Turtle())
            context.load(Meta())
            context.load(CoreLib!)
            
            try! program.execute(context: context, reuseScope: false)

            let result = try! SVGEncoder().encode(context: context)
            let fixture = try! String(contentsOf: Bundle.module.url(forResource: "logo", withExtension: "svg")!)
            
            AssertMatchMultilineString(result, fixture, separator: "\n")
            
            // TODO: Syntax coloring
        }
    }
    
    func testFlower() {
        let program =   """
                        make [:turnAmount, 10]
                        make [:stepPerTurn, 20]
                        make [:counter, 0]
                        repeat [558, [
                            if [counter > 360 / 12, [
                                make [:counter, 0]
                                lt [turnAmount * 5]
                            ]]
                            make [:counter, counter + 1]
                            repeat [turnAmount, [
                                rt [1]
                                fd [stepPerTurn / turnAmount]
                            ]]
                        ]]

                        ht []
                        """
        let parser = OgolParser()
        parser.modules = [Turtle(), Meta(), CoreLib!]
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
            context.load(Turtle())
            context.load(Meta())
            context.load(CoreLib!)

            try! program.execute(context: context, reuseScope: false)

            
            _ = try! SVGEncoder().encode(context: context)
        }
        
    }
    
    func testLogicalExpressions() {
        let source = """
                     make [:conditionT1, 14 < 15]
                     make [:conditionF1, 8 > 12]
                     make [:twelve, 12]
                     make [:otherTwelve, 11 + 1]
                     make [:conditionT2, twelve = otherTwelve]

                     if [conditionT1, [
                         make [:cP1, "pass"]
                     ]]
                     make [:cF1, "pass"]
                     if [conditionF1, [
                         make [:cF1, "fail"]
                     ]]
                     if [conditionT2, [
                         make [:cP2, "pass"]
                     ]]
                     """
        let parser = OgolParser()
        parser.modules = [Turtle(), Optimizer(), Meta()]
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse logical test program")
            return
        }
        
        // execute
        
        let context: ExecutionContext = ExecutionContext()
        context.load(Turtle())
        context.load(Meta())
        context.load(CoreLib!)
        context.variables["cP1"] = .string("")
        context.variables["cP2"] = .string("")
        context.variables["cF1"] = .string("")
        try! program.execute(context: context, reuseScope: false)
        
        guard case let .string(cP1) = context.variables["cP1"],
              case let .string(cP2) = context.variables["cP2"],
              case let .string(cF1) = context.variables["cF1"] else {
            XCTFail()
            return
        }
        XCTAssertEqual(cP1, "pass")
        XCTAssertEqual(cP2, "pass")
        XCTAssertEqual(cF1, "pass")
    }
    
    func testPrepend() throws {
        let source =
            """
            make[:l,list[1,2,3]]
            make[:l2, List.prepend[0, l]]
            List.prepend[-1, :l]
            """
        let parser = OgolParser()
        parser.modules = [Meta(), CoreLib!]
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse logical test program")
            return
        }
        let context: ExecutionContext = ExecutionContext()
        context.variables["l"] = .list([])
        context.variables["l2"] = .list([])
        context.load(Meta())
        context.load(CoreLib!)
        try! program.execute(context: context, reuseScope: false)
            
        guard case let .list(l) = context.variables["l"],
              case let .list(l2) = context.variables["l2"] else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(l, [-1.0, 1.0, 2.0, 3.0].map { Bottom.double($0) })
        XCTAssertEqual(l2, [0.0, 1.0, 2.0, 3.0].map { Bottom.double($0) })
    }
    
    func testAppend() throws {
        let source =
            """
            make[:l,list[1,2,3]]
            make[:l2, List.append[4, l]]
            List.append[5, :l]
            """
        let parser = OgolParser()
        parser.modules = [Meta(), CoreLib!]
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse logical test program")
            return
        }
        let context: ExecutionContext = ExecutionContext()
        context.variables["l"] = .list([])
        context.variables["l2"] = .list([])
        context.load(Meta())
        context.load(CoreLib!)
        try! program.execute(context: context, reuseScope: false)
            
        guard case let .list(l) = context.variables["l"],
              case let .list(l2) = context.variables["l2"] else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(l, [1.0, 2.0, 3.0, 5.0].map { Bottom.double($0) })
        XCTAssertEqual(l2, [1.0, 2.0, 3.0, 4.0].map { Bottom.double($0) })
    }
    
    func testInvoke() throws {
        let source =
            """
            make[:five,invoke[:add,2,3]] ; invoke with 2 parameters
            
            to makeSeven[]
                make[:seven, 7]
            end
            invoke[:makeSeven] ; invoke with no parameters
            """
        let parser = OgolParser()
        parser.modules = [Meta(), CoreLib!]
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse logical test program")
            return
        }
        let context: ExecutionContext = ExecutionContext()
        context.variables["five"] = .list([])
        context.variables["seven"] = .list([])
        context.load(Meta())
        context.load(CoreLib!)
        try! program.execute(context: context, reuseScope: false)
        
        guard case let .double(five) = context.variables["five"],
              case let .double(seven) = context.variables["seven"] else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(five, 5)
        XCTAssertEqual(seven, 7)
    }
    
    func testBF() throws {
        let source =
            """
            make[:l1,List.butFirst[list[1,2,3]]]
            make[:l2,List.butFirst[list[3]]]
            make[:l3,List.butFirst[list[]]]
            """
        let parser = OgolParser()
        parser.modules = [Meta(), CoreLib!]
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse logical test program")
            return
        }
        let context: ExecutionContext = ExecutionContext()
        context.variables["l1"] = .double(0)
        context.variables["l2"] = .double(0)
        context.variables["l3"] = .double(0)
        context.load(Meta())
        context.load(CoreLib!)
        try! program.execute(context: context, reuseScope: false)
            
        guard case let .list(l1) = context.variables["l1"],
              case let .list(l2) = context.variables["l2"],
              case let .list(l3) = context.variables["l3"] else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(l1, [2.0, 3.0].map { Bottom.double($0) })
        XCTAssertEqual(l2, [])
        XCTAssertEqual(l3, [])
    }
    
    func testBL() throws {
        let source =
            """
            make[:l1,List.butLast[list[1,2,3]]]
            make[:l2,List.butLast[list[3]]]
            make[:l3,List.butLast[list[]]]
            """
        let parser = OgolParser()
        parser.modules = [Meta(), CoreLib!]
        guard case let .success(program, _, _) = parser.program(substring: Substring(source)) else {
            XCTFail("Failed to parse logical test program")
            return
        }
        let context: ExecutionContext = ExecutionContext()
        context.variables["l1"] = .double(0)
        context.variables["l2"] = .double(0)
        context.variables["l3"] = .double(0)
        context.load(Meta())
        context.load(CoreLib!)
        try! program.execute(context: context, reuseScope: false)
            
        guard case let .list(l1) = context.variables["l1"],
              case let .list(l2) = context.variables["l2"],
              case let .list(l3) = context.variables["l3"] else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(l1, [1.0, 2.0].map { Bottom.double($0) })
        XCTAssertEqual(l2, [])
        XCTAssertEqual(l3, [])
    }
}

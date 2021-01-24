//
//  CoreLibTests.swift
//  
//
//  Created by Fabián Cañas on 3/11/21.
//

import Execution
@testable import libOgol
import OgoLang

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

class CoreLibTests: XCTestCase {
    func testInlineEqualsFile() throws {
        guard let url = Bundle.module.url(forResource: "CoreLib", withExtension: "ogol"), let string = try? String(contentsOf: url) else {
            XCTFail()
            return
        }
        AssertMatchMultilineString(CoreLibString, string, separator: "\n")
    }
}

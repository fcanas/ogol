//
//  CLI.swift
//  FFCParserCombinator
//
//  Created by Fabián Cañas on 5/17/20.
//

import Foundation
import LogoLang

struct CLI: Module {
    static var procedures: [String : Procedure] {
        return [
            "print" : .extern(_print),
            "po" : .extern(po)
        ]
    }

    private static let _print = NativeProcedure(name: "print", parameters: ["in"]) { (params, _) in
        print(params.first!.description)
        return nil
    }

    private static let po = NativeProcedure(name: "po", parameters: ["param"]) { (params, context) in
        if params.first == .string("names") {
            print(context.allVariables())
        } else if params.first == .string("procedures") {
            print(context.allProcedures())
        } else {
            print("unrecognized parameter \(params.first!)")
        }

        return nil
    }
}

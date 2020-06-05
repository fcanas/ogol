//
//  Repl.swift
//  exLogo
//
//  Created by Fabian Canas on 6/4/20.
//

import Foundation
import LogoLang

struct CLI: Module {
    
    static var message: (String) -> Void = { _ in }
    static var clear: () -> Void = {  }
    
    static var procedures: [String : Procedure] {
        return [
            "print" : _print,
            "po" : po,
            "clear" : _clear
        ]
    }
    
    private static let _print = NativeProcedure(name: "print", parameters: ["in"]) { (params, _) in
        message(params.first!.description)
        return nil
    }

    private static let _clear = NativeProcedure(name: "clear", parameters: []) { (params, _) in
        clear()
        return nil
    }

    private static let po = NativeProcedure(name: "po", parameters: ["param"]) { (params, context) in
        if params.first == .string("names") {
            message(context.allVariables().description)
        } else if params.first == .string("procedures") {
            message(context.allProcedures().description)
        } else {
            message("unrecognized parameter \(params.first!)")
        }

        return nil
    }
}

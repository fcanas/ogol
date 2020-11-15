//
//  NativeModules.swift
//  OgoLang
//
//  Created by Fabian Canas on 7/21/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Execution

public struct NativeModule: Module {
    
    public var procedures: [String : Procedure]
    
    public init?(string: String, parser: LanguageParser, optimize: Bool = true) {
        let parseResult = parser.program(substring: Substring(string))
        
        let program: Program
        switch parseResult {
        case let .success(p, syntax, error):
            self.syntaxMap = syntax
            program = p
            print(error)
        case let .error(e):
            print("Unable to load native module: \(e)")
            return nil
        }
        
        self.inputString = string
        
        if optimize {
            let reducedProcedures = program.procedures.map({ (key: String, value: Procedure) -> (String, Procedure) in
                switch value {
                
                case let .native(native):
                    native.reduceExpressions()
                    return (key, .native(native))
                case .extern(_):
                    return (key, value)
                }
            })
            self.procedures = Dictionary(uniqueKeysWithValues: reducedProcedures)
        } else {
            self.procedures = program.procedures
        }
    }
    
    var inputString: String
    var syntaxMap: [Range<Substring.Index>:SyntaxColorable]
}

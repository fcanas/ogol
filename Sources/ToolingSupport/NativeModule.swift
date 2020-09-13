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
        guard case let .success(program, syntaxMap, _) = parser.program(substring: Substring(string)) else {
            // failed to parse
            return nil
        }
        self.inputString = string
        self.syntaxMap = syntaxMap
        
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

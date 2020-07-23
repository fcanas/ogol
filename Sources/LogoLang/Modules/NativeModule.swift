//
//  NativeModules.swift
//  LogoLang
//
//  Created by Fabian Canas on 7/21/20.
//

import Foundation

public struct NativeModule: Module {
    
    public var procedures: [String : Procedure]
    
    public init?(string: String) {
        let parser = LogoParser()
        guard case let .success(program, syntaxMap, _) = parser.program(substring: Substring(string)) else {
            // failed to parse
            return nil
        }
        self.inputString = string
        self.syntaxMap = syntaxMap
        self.procedures = program.procedures
    }
    
    var inputString: String
    var syntaxMap: [Range<Substring.Index>:SyntaxColorable]
}

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
    public var initialize: (ExecutionContext)->Void
    
    public init?(string: String, parser: LanguageParser, optimize: Bool = true, initialize: @escaping (ExecutionContext)->Void = { _ in }) {
        let parseResult = parser.program(substring: Substring(string))
        self.initialize = initialize
        
        let program: Program
        switch parseResult {
        case let .success(p, syntax, error):
            self.syntaxMap = syntax
            self.errorMap = error
            program = p
            if !error.isEmpty {
                print(error)
            }
        case .error(_):
            // TODO: sane logging
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
    public var syntaxMap: [Range<Substring.Index>:SyntaxColorable]
    public var errorMap: [Range<Substring.Index>:ParseError]
    
    public func initialize(context: ExecutionContext) {
        self.initialize(context)
    }
}

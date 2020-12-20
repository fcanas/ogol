//
//  Parsing.swift
//  OgoLang.ToolingSupport
//
//  Created by Fabian Canas on 8/17/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Execution

public enum ParseError {
    case basic(String)
    case anticipatedRuntime(String)
    case severeInternal(String)
}

public enum ParseResult {
    case success(Program, [Range<Substring.Index>:SyntaxColorable], [Range<Substring.Index>:ParseError])
    case error([Range<Substring.Index>:ParseError])
}

public protocol LanguageParser: AnyObject {
    func program(substring: Substring) -> ParseResult
    
    var modules: [Module] { get set }
    var additionalProcedures: [String:Procedure] { get set }
}

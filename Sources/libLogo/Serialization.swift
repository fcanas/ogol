//
//  Serialization.swift
//  exLogo
//
//  Created by Fabian Canas on 6/8/20.
//

import Foundation
import LogoLang


public class Serialization: Module {
    
    public static var procedures: [String : Procedure] = ["proc":.extern(Serialization.proc)]
    
    static var proc: ExternalProcedure = {
       
        ExternalProcedure(name: "proc", parameters: ["name"]) { (param, context) -> Bottom? in
            guard case let .string(procedureName) = param.first else {
                throw ExecutionHandoff.error(ExecutionHandoff.Runtime.parameter, "serializing a procedure needs to know which procedure")
            }
            guard let procedure = context.procedures[procedureName] else {
                throw ExecutionHandoff.error(ExecutionHandoff.Runtime.missingSymbol, "trying to serialize \(procedureName), procedure not found")
            }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let encodedProcedure = try encoder.encode(procedure)
                let encString = String(data: encodedProcedure, encoding: .utf8)!
                return .string(encString)
            } catch is LogoCodingError {
                
            }
            
            return nil
        }
        
    }()
    
}

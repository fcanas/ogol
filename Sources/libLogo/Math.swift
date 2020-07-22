//
//  Math.swift
//  LogoLang
//
//  Created by Fabián Cañas on 5/17/20.
//

import Foundation
import LogoLang

public struct LogoMath: Module {
    
    public init() {}

    private struct SingleParameter: Module {

        private let nativeFunctions: [String:(Double)->Double] = [
            "cos" : Darwin.cos,
            "sin" : Darwin.sin,
            "tan" : Darwin.tan,
            "acos" : Darwin.acos,
            "asin" : Darwin.asin,
            "atan" : Darwin.atan,

            "cosh" : Darwin.cosh,
            "sinh" : Darwin.sinh,
            "tanh" : Darwin.tanh,
            "acosh" : Darwin.acosh,
            "asinh" : Darwin.asinh,
            "atanh" : Darwin.atanh,

            "exp" : Darwin.exp,
            "exp2" : Darwin.exp2,

            "lgamma" : Darwin.lgamma,
            "tgamma" : Darwin.tgamma,

            "log" : Darwin.log,
            "log10" : Darwin.log10,
            "log2" : Darwin.log2,
            "abs" : Darwin.fabs,
            "sqrt" : Darwin.sqrt,
        ]

        public var procedures: [String : Procedure] {
            var out: [String:Procedure] = [:]
            self.nativeFunctions.forEach { (key: String, function: @escaping (Double) -> Double) in
                out[key] = Procedure.extern(ExternalProcedure(name: key, parameters: ["LogoMathParam"]) { (params, context) throws -> Bottom? in
                    guard case let .double(param) = params.first else {
                        throw ExecutionHandoff.error(.parameter, "\(key) needs a numeric parameter")
                    }
                    return Bottom.double(function(param))
                })
            }
            return out
        }
    }

    private struct Random: Module {
        
        public let procedures: [String : Procedure] = {
            return ["random":.extern(ExternalProcedure(name: "random", parameters: ["top"], action: { (params, _) -> Bottom? in
                guard case let .double(param) = params.first else {
                    throw ExecutionHandoff.error(.parameter, "random needs a numeric parameter")
                }
                return .double(Double(arc4random() % UInt32(param)))
            }))]
        }()
    }

    public let procedures: [String : Procedure] = {
        return SingleParameter().procedures.merging(Random().procedures, uniquingKeysWith: { (a,b) in a })
    }()

}



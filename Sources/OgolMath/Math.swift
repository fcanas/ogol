//
//  Math.swift
//  OgoLang.libOgol
//
//  Created by Fabián Cañas on 5/17/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Execution
import Foundation
import OgoLang
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

public struct LogoMath: Module {
    
    public init() {}

    private struct SingleParameter: Module {

        private let nativeFunctions: [String:(Double)->Double] = [
            "cos" : cos,
            "sin" : sin,
            "tan" : tan,
            "acos" : acos,
            "asin" : asin,
            "atan" : atan,

            "cosh" : cosh,
            "sinh" : sinh,
            "tanh" : tanh,
            "acosh" : acosh,
            "asinh" : asinh,
            "atanh" : atanh,

            "exp" : exp,
            "exp2" : exp2,

            "lgamma" : lgamma,
            "tgamma" : tgamma,

            "log" : log,
            "log10" : log10,
            "log2" : log2,
            "abs" : fabs,
            "sqrt" : sqrt,
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
                let ceiling = UInt32(param)
                guard ceiling > 0 else {
                    return .double(0)
                }
                let value = Double(arc4random() % ceiling)
                return .double(value)
            }))]
        }()
    }

    public let procedures: [String : Procedure] = {
        return SingleParameter().procedures.merging(Random().procedures, uniquingKeysWith: { (a,b) in a })
    }()
}

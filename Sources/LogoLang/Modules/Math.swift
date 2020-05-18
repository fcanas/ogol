//
//  Math.swift
//  FFCParserCombinator
//
//  Created by Fabián Cañas on 5/17/20.
//

import Foundation

public protocol Module {
    static var procedures: [String : NativeProcedure] { get }
}

public struct LogoMath: Module {

    private static let nativeFunctions: [String:(Double)->Double] = [
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
    ]

    public static let procedures: [String : NativeProcedure] = {
        var out: [String:NativeProcedure] = [:]
        nativeFunctions.forEach { (key: String, function: @escaping (Double) -> Double) in
            out[key] = NativeProcedure(name: key, parameters: [Value.deref("LogoMathParam")]) { (params, context) throws -> Bottom? in
                guard case let .double(param) = params.first else {
                    throw ExecutionHandoff.error(.parameter, "\(key) needs a numeric parameter")
                }
                return Bottom.double(function(param))
            }
        }
        return out
    }()
}



//
//  Repl.swift
//  Ogol.ToolingSupport
//
//  Created by Fabian Canas on 9/13/20.
//

import Execution
import Foundation

extension Substring.Index {
    func idx(in substring: Substring) -> Int {
        return substring.distance(from: substring.startIndex, to: self)
    }
}

public func startRepl(parser: LanguageParser, modules: [Module]) {
    var procs: [String:Procedure] = [:]

    let context: ExecutionContext = ExecutionContext(procedures: procs)

    modules.forEach { context.load($0) }
    parser.modules = modules

    let prompt = "> "
    print(prompt, terminator: "")
    while let input = readLine() {
        let substringInput = Substring(input)
        let result = parser.program(substring: substringInput)
        switch result {
        case let .success(program, _, _):
            do {
                program.procedures.forEach { (key: String, value: Procedure) in
                    procs[key] = value
                }
                context.inject(procedures: procs)
                try program.commands.forEach { (c) in
                    try c.execute(context: context, reuseScope: false)
                }
            } catch let Execution.ExecutionHandoff.error(runtimeError, message) {
                switch runtimeError {
                case .typeError:
                    print("Type Error", terminator: "")
                case .missingSymbol:
                    print("Missing Symbol", terminator: "")
                case .maxDepth:
                    print("Stack depth exceeded", terminator: "")
                case .parameter:
                    print("Parameter Error", terminator: "")
                case .noOutput:
                    print("Procedure provided no output when expected", terminator: "")
                case .module:
                    print("Module error", terminator: "")
                }
                print(" - " + message)
            } catch let Execution.ExecutionHandoff.output(v) {
                print(v)
            } catch let runtimeError {
                print(runtimeError)
            }
        case let .error(error):
            if let e = error.first {
                let startIndex = e.key.lowerBound.idx(in: substringInput)
                let length = e.key.upperBound.idx(in: substringInput) - startIndex
                print(String(repeating: " ", count: startIndex + prompt.count) + "^" + String(repeating: "~", count: length-1))
                switch e.value {
                    
                case let .basic(message):
                    print(message)
                case .anticipatedRuntime(_):
                continue // todo : weird
                case let .severeInternal(e):
                    print("Severe internal error: \(e)")
                }
                print(input)
            }
        }
        print(prompt, terminator: "")
    }
}

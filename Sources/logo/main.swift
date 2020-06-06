import Foundation
import LogoLang
import libLogo

var procs: [String:Procedure] = [:]

extension Substring.Index {
    func idx(in substring: Substring) -> Int {
        return substring.distance(from: substring.startIndex, to: self)
    }
}
var context: ExecutionContext = ExecutionContext(procedures: procs)
context.load(Turtle.self)

context.load(CLI.self)
context.load(LogoMath.self)
context.load(Turtle.self)

let prompt = "> "
let parser = LogoParser()
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
        } catch let LogoLang.ExecutionHandoff.error(runtimeError, message) {
            switch runtimeError {
            case .typeError:
                print("Type Error", terminator: "")
            case .missingSymbol:
                print("Missing Symbol", terminator: "")
            case .maxDepth:
                print("Stack depth exceeded", terminator: "")
            case .corruptAST:
                print("Corrupt AST", terminator: "")
            case .parameter:
                print("Parameter Error", terminator: "")
            case .noOutput:
                print("Procedure provided no output when expected", terminator: "")
            case .module:
                print("Module error", terminator: "")
            }
            print(" - " + message)
        } catch let LogoLang.ExecutionHandoff.output(v) {
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


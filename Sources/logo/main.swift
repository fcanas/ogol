import Foundation
import LogoLang

var procs: [String:Procedure] = [:]

procs["print"] = NativeProcedure(name: "print", parameters: [Value.deref("in")]) { (params, _) in
    switch params.first! {
    case let .double(number):
        print("\(number)")
    case let .string(string):
        print(string)
    }
    return nil
}

procs["dump"] = NativeProcedure(name: "dump", parameters: []) { (_, context) in
    print(context.allVariables())
    return nil
}

extension Substring.Index {
    func idx(in substring: Substring) -> Int {
        return substring.distance(from: substring.startIndex, to: self)
    }
}

var context: ExecutionContext? = try ExecutionContext(parent: nil, procedures: procs)
let prompt = "> "
let parser = LogoParser()
print(prompt, terminator: "")
while let input = readLine() {
    let substringInput = Substring(input)
    let result = parser.program(substring: substringInput)
    switch result {
    case let .success(program, _, _):
        do {
            try program.commands.forEach { (c) in
                try c.execute(context: &context)
            }
        } catch let LogoLang.ExecutionHandoff.error(runtimeError, message) {
            switch runtimeError {
            case .typeError:
                print("Type Error")
            case .missingSymbol:
                print("Missing Symbol")
            case .maxDepth:
                print("Stack depth exceeded")
            case .corruptAST:
                print("Corrupt AST")
            case .parameter:
                print("Parameter Error")
            }
            print(message)
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
                print("Severe internall error: \(e)")
            }
            print(input)
        }
    }
    print(prompt, terminator: "")
}


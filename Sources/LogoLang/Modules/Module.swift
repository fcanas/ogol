//
//  Module.swift
//  LogoLang
//
//  Created by Fabian Canas on 6/2/20.
//

public protocol Module {
    static var procedures: [String : Procedure] { get }
    static func initialize(context: ExecutionContext)
}

extension Module {
    public static func initialize(context: ExecutionContext) {}
}

public class NativeProcedure: Procedure {

    public override var description: String {
        return "Native Procedure \(parameters)"
    }

    let action: ([Bottom], ExecutionContext) throws -> Bottom?
    
    public init(name: String, parameters: [String], action: @escaping ([Bottom], ExecutionContext) throws -> Bottom?) {
        self.action = action
        super.init(name: name, commands: [], procedures: [:], parameters: parameters.map(Value.deref))
    }
    
    public override func execute(context: inout ExecutionContext?) throws {
        let p = try parameters.map { (deref) -> Bottom in
            guard case let .deref(s) = deref  else {
                throw ExecutionHandoff.error(.typeError, "Parameters should be derefs")
            }
            guard let v = context?.variables[s] else {
                throw ExecutionHandoff.error(.missingSymbol, "\(s) parameter required")
            }
            return v
        }
        if let output = try action(p, context!) {
            throw ExecutionHandoff.output(output)
        }
    }
}

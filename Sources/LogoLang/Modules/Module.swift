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

public class NativeProcedure: GenericProcedure {

    public var name: String
    public var parameters: [String]
    public var procedures: [String : Procedure]
    
    public var description: String {
        return "Native Procedure \(parameters)"
    }

    let action: ([Bottom], ExecutionContext) throws -> Bottom?
    
    public init(name: String, parameters: [String], action: @escaping ([Bottom], ExecutionContext) throws -> Bottom?) {
        self.name = name
        self.parameters = parameters
        self.action = action
        self.procedures = [:]
    }
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let p = try parameters.map { (parameterName) -> Bottom in
            guard let v = context.variables[parameterName] else {
                throw ExecutionHandoff.error(.missingSymbol, "\(parameterName) parameter required")
            }
            return v
        }
        if let output = try action(p, context) {
            throw ExecutionHandoff.output(output)
        }
    }
}

//
//  Command.swift
//  LogoLang
//
//  Created by Fabián Cañas on 3/1/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

public struct CommandList: Codable, Equatable {
    
    public var description: String { get { "[]-> " + commands.description } }

    var commands: [ExecutionNode]

    var procedures: [String : Procedure]
    
    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        let context: ExecutionContext = reuseScope ? context : try ExecutionContext(parent: context, procedures: procedures)
        for command in commands {
            try command.execute(context: context, reuseScope: false) // todo, last command in block?
        }
    }
    
    public init(commands: [ExecutionNode], procedures: [String : Procedure]) {
        self.commands = commands
        self.procedures = procedures
    }

}

public struct Conditional: Codable, Equatable {

    public var description: String {
        return "\(condition) [ \(block) ]"
    }

    var condition: Expression
    var block: CommandList

    public init(condition: Expression, block: CommandList) {
        self.condition = condition
        self.block = block
    }

    public func execute(context: ExecutionContext, reuseScope: Bool) throws {
        guard case let .boolean(conditionValue) = try condition.evaluate(context: context) else {
                throw ExecutionHandoff.error(.typeError, "Conditional require a logical condition")
        }
        if conditionValue {
            try block.execute(context: context, reuseScope: reuseScope)
        }
    }

}

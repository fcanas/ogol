//
//  TurtleGraphics.swift
//  Logo
//
//  Created by Fabian Canas on 10/27/18.
//  Copyright © 2018 Fabian Canas. All rights reserved.
//

import Foundation

public struct Point {
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public let x: Double
    public let y: Double
    
    public static func + (_ lhs: Point, _ rhs: Point) -> Point {
        return Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    public static func - (_ lhs: Point, _ rhs: Point) -> Point {
        return Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    public static let zero = Point(x: 0, y: 0)
}

public class Turtle: Module {
    
    private static let ModuleStoreKey: String = "turtle"
    static let turtleKey = ExecutionContext.ModuleKey<Turtle>(key: "turtle")
    static let multilineKey = ExecutionContext.ModuleKey<[MultiLine]>(key: "multiline")
    
    public static var procedures: [String : Procedure] = {
        var out: [String:Procedure] = [:]
        Command.Partial.allCases.forEach { (partial) in
            out[partial.rawValue] = partial
        }
        return out
    }()
    
    public static func initialize(context: ExecutionContext) {
        let turtleStore = ExecutionContext.ModuleStore()
        context.moduleStores[ModuleStoreKey] = turtleStore
        turtleStore[turtleKey] = Turtle()
    }
    
    public static func multilines(for context:ExecutionContext) -> [MultiLine] {
        return context.moduleStores[ModuleStoreKey]?[multilineKey] ?? []
    }
    
    public static func from(context: ExecutionContext) -> Turtle? {
        return context.moduleStores[Turtle.ModuleStoreKey]?[Turtle.turtleKey]
    }
    
    public enum Command {
        var description: String {
            switch self {
            case let .fd(v): return "fd \(v)"
            case let .bk(v): return "bk \(v)"
            case let .rt(v): return "rt \(v)"
            case let .lt(v): return "lt \(v)"
            case .cs: return "cs"
            case .pu: return "pu"
            case .pd: return "pd"
            case .st: return "st"
            case .ht: return "ht"
            case .home: return "home"
            case let .setXY(point): return "setxy \(point)"
            }
        }
        
        fileprivate enum Partial: String, RawRepresentable, CaseIterable, Procedure {

            var description: String { self.rawValue }
            
            var name: String { self.rawValue }
            
            private static let emptyProcedure: [String:Procedure] = [:]
            
            var procedures: [String : Procedure] { Partial.emptyProcedure }
            
            func execute(context: ExecutionContext) throws {
                switch self {
                case .cs:
                    try Turtle.Command.cs.execute(context: context)
                case .pu:
                    try Turtle.Command.pu.execute(context: context)
                case .pd:
                    try Turtle.Command.pd.execute(context: context)
                case .st:
                    try Turtle.Command.st.execute(context: context)
                case .ht:
                    try Turtle.Command.ht.execute(context: context)
                case .home:
                    try Turtle.Command.home.execute(context: context)
                case .fd:
                    guard case let .double(v) = context.variables["amount"] else {
                        throw ExecutionHandoff.error(.typeError, "Expected a number.")
                    }
                    try Turtle.Command.fd(v).execute(context: context)
                case .bk:
                    guard case let .double(v) = context.variables["amount"] else {
                        throw ExecutionHandoff.error(.typeError, "Expected a number.")
                    }
                    try Turtle.Command.bk(v).execute(context: context)
                case .lt:
                    guard case let .double(v) = context.variables["amount"] else {
                        throw ExecutionHandoff.error(.typeError, "Expected a number.")
                    }
                    try Turtle.Command.lt(v).execute(context: context)
                case .rt:
                    guard case let .double(v) = context.variables["amount"] else {
                        throw ExecutionHandoff.error(.typeError, "Expected a number.")
                    }
                    try Turtle.Command.rt(v).execute(context: context)
                case .setxy:
                    guard case let .double(x) = context.variables["x"] else {
                        throw ExecutionHandoff.error(.typeError, "Expected a number for X.")
                    }
                    guard case let .double(y) = context.variables["y"] else {
                        throw ExecutionHandoff.error(.typeError, "Expected a number for Y.")
                    }
                    try Turtle.Command.setXY(Point(x: x, y: y)).execute(context: context)
                }
            }
            
            case fd
            case bk
            case rt
            case lt
            case cs
            case pu
            case pd
            case st
            case ht
            case home
            case setxy
            
            var parameterCount: Int {
                switch self {
                case .fd, .bk, .rt, .lt:
                    return 1
                case .cs, .pu, .pd, .st, .ht, .home:
                    return 0
                case .setxy:
                    return 2
                }
            }
            
            public var parameters: [String] {
                switch self {
                case .fd, .bk, .rt, .lt:
                    return ["amount"]
                case .setxy:
                    return ["x", "y"]
                default:
                    return []
                }
            }
            
        }
        
        case fd(Double)
        case bk(Double)
        case rt(Double)
        case lt(Double)
        case cs
        case pu
        case pd
        case st
        case ht
        case home
        case setXY(Point)
        
        func execute(context: ExecutionContext) throws {
            
            guard let store = context.moduleStores[Turtle.ModuleStoreKey] else {
                throw ExecutionHandoff.error(.module, "Turtle module not initialized")
            }
            
            guard let turtle = store[turtleKey] else {
                throw ExecutionHandoff.error(.module, "Turtle not found")
            }
            
            if case .cs = self {
                store[multilineKey] = []
                return
            }
            
            let newMultiline = turtle.performing(self)
            if let newMultiline = newMultiline {
                if (store[multilineKey] != nil) {
                    store[multilineKey]?.append(newMultiline)
                } else {
                    store[multilineKey] = [newMultiline]
                }
            }
        }
    }
    
    public enum Pen {
        case up
        case down
    }
    
    public struct Segment {
        public let start: Point
        public let end: Point
    }
    
    public typealias MultiLine = Array<Turtle.Segment>
    
    public static let defaultAngle: Double = -90
    
    public var position: Point
    public var angle: Double
    public var pen: Pen
    public var visible: Bool
    public var multiline: MultiLine
    
    public init(position: Point = .zero,
                angle: Double = Turtle.defaultAngle,
                pen: Pen = .down,
                visible: Bool = true,
                multiline: MultiLine = []
    ) {
        self.position = position
        self.angle = angle
        self.pen = pen
        self.visible = visible
        self.multiline = multiline
    }
    
    func performing(_ command: Turtle.Command) -> MultiLine? {
        switch command {
        case let .fd(dist):
            let a = angle * .pi / 180
            let newPosition = position + Point(x: cos(a) * dist, y: sin(a) * dist)
            if pen == .down {
                self.multiline.append(Segment(start: position, end: newPosition))
            }
            position = newPosition
        case let .bk(dist):
            let a = angle * .pi / 180
            let newPosition = position - Point(x: cos(a) * dist, y: sin(a) * dist)
            if pen == .down {
                self.multiline.append(Segment(start: position, end: newPosition))
            }
            position = newPosition
        case let .lt(a):
            angle += a
        case let .rt(a):
            angle -= a
        case .pu:
            pen = .up
            let oldML = multiline
            multiline = []
            return oldML
        case .pd:
            pen = .down
        case .home:
            position = .zero
            angle = Turtle.defaultAngle
            let oldML = multiline
            multiline = []
            return oldML
        case .st:
            visible = true
        case .ht:
            visible = false
        case let .setXY(position):
            self.position = position
            let oldML = multiline
            multiline = []
            return oldML
        case .cs:
            multiline = []
        }
        return nil
    }
}


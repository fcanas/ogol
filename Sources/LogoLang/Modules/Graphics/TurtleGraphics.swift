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

public struct Turtle: Module {

    private static let ModuleStoreKey: String = "turtle"
//    let turtleKey = Turtle.turtleKey
    static let turtleKey = ExecutionContext.ModuleKey<Turtle>(key: "turtle")
    static let multilineKey = ExecutionContext.ModuleKey<[MultiLine]>(key: "multiline")
//    let multilineKey = Turtle.multilineKey

    public static var procedures: [String : Procedure] = {
        var out: [String:Procedure] = [:]
        Command.Partial.allCases.forEach { (partial) in
            out[partial.rawValue] = partial.procedure()
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

            fileprivate enum Partial: String, RawRepresentable, CaseIterable {
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
                
                func parameterNames() -> [String] {
                    switch self {
                    case .fd, .bk, .rt, .lt:
                        return ["amount"]
                    case .setxy:
                        return ["x", "y"]
                    default:
                        return []
                    }
                }
                
                func procedure() -> NativeProcedure {
                    
                    NativeProcedure(name: self.rawValue, parameters: self.parameterNames()) { (parameters, context) -> Bottom? in
                        guard self.parameterCount == parameters.count else {
                            throw ExecutionHandoff.error(.parameter, "Expected \(self.parameterCount) parameters, found \(parameters.count)")
                        }
                        let turtleCommand: Turtle.Command

                        let evaluatedParameters = try parameters.map { (value) throws -> Double in
                            guard case let .double(v) = value else {
                                throw ExecutionHandoff.error(.typeError, "Expected a number.")
                            }
                            return v
                        }

                        switch self {
                        case .fd:
                            turtleCommand = .fd(evaluatedParameters[0])
                        case .bk:
                            turtleCommand = .bk(evaluatedParameters[0])
                        case .rt:
                            turtleCommand = .rt(evaluatedParameters[0])
                        case .lt:
                            turtleCommand = .lt(evaluatedParameters[0])
                        case .cs:
                            turtleCommand = .cs
                        case .pu:
                            turtleCommand = .pu
                        case .pd:
                            turtleCommand = .pd
                        case .st:
                            turtleCommand = .st
                        case .ht:
                            turtleCommand = .ht
                        case .home:
                            turtleCommand = .home
                        case .setxy:
                            turtleCommand = .setXY(Point(x: evaluatedParameters[0], y: evaluatedParameters[1]))
                        }
                        try turtleCommand.execute(context: context)
                        return nil
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

                let (newTurtle, newMultiline) = turtle.performing(self)
                store[turtleKey] = newTurtle
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

    func with(position: Point? = nil,
              angle: Double? = nil,
              pen: Pen? = nil,
              visible: Bool? = nil,
              multiline: MultiLine? = nil
        ) -> Turtle {
        return Turtle(position: position ?? self.position,
                      angle: angle ?? self.angle,
                      pen: pen ?? self.pen,
                      visible: visible ?? self.visible,
                      multiline: multiline ?? self.multiline
        )
    }

    func performing(_ command: Turtle.Command) -> (Turtle, MultiLine?) {
        let out = with(command)
        let lineOut: MultiLine?

        switch command {

        case .pu, .setXY(_), .home:
            lineOut = multiline
        default:
            lineOut = nil
        }

        return (out, lineOut)
    }

    func with(_ command: Turtle.Command) -> Turtle {
        switch command {
        case let .fd(dist):
            let a = angle * .pi / 180
            let multiLine: MultiLine
            let newPosition = position + Point(x: cos(a) * dist, y: sin(a) * dist)
            if pen == .down {
                multiLine = self.multiline + [Segment(start: position, end: newPosition)]
            } else {
                multiLine = self.multiline
            }
            return with(position: newPosition, multiline: multiLine)
        case let .bk(dist):
            let a = angle * .pi / 180
            let multiLine: MultiLine
            let newPosition = position - Point(x: cos(a) * dist, y: sin(a) * dist)
            if pen == .down {
                multiLine = self.multiline + [Segment(start: position, end: newPosition)]
            } else {
                multiLine = self.multiline
            }
            return with(position: newPosition, multiline: multiLine)
        case let .lt(a):
            return with(angle: angle + a)
        case let .rt(a):
            return with(angle: angle - a)
        case .pu:
            return with(pen: .up, multiline: [])
        case .pd:
            return with(pen: .down)
        case .home:
            return with(position:.zero, angle: Turtle.defaultAngle, multiline: [])
        case .st:
            return with(visible: true)
        case .ht:
            return with(visible: false)
        case let .setXY(position):
            return with(position: position, multiline: [])
        case .cs:
            return with(multiline: [])
        }
    }
}

public struct Canvas {
    public let turtle: Turtle
    public let multiLines: [Turtle.MultiLine]

    public init(turtle: Turtle, multiLines: [Turtle.MultiLine] = []) {
        self.turtle = turtle
        self.multiLines = multiLines
    }

    public func performing(_ command: Turtle.Command) -> Canvas {
        let (t, m) = turtle.performing(command)
        return Canvas(turtle: t, multiLines: m.map { self.multiLines + [$0] } ?? multiLines )
    }
}


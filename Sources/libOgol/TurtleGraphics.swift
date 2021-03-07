//
//  TurtleGraphics.swift
//  OgoLang.libOgol
//
//  Created by Fabian Canas on 10/27/18.
//  Copyright © 2018 Fabian Canas. All rights reserved.
//

import Execution
import Foundation
import OgoLang

public protocol Drawable {
    var color: [Double]? { get }
}

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

public struct Label: Drawable {
    public var position: Point
    public var angle: Double
    public var text: String
    public var color: [Double]?
}

public class Turtle: Module {
    
    internal static let ModuleStoreKey: String = "turtle"
    internal static let turtleKey = ExecutionContext.ModuleStore.Key<Turtle>(key: "turtle")
    internal static let multilineKey = ExecutionContext.ModuleStore.Key<[Drawable]>(key: "multiline")
    internal static let boundsKey = ExecutionContext.ModuleStore.Key<Bounds>(key: "bounds")
    
    public var procedures: [String : Procedure] = {
        var out: [String:Procedure] = [:]
        Command.Partial.allCases.forEach { (partial) in
            out[partial.rawValue] = .extern(partial)
        }
        return out
    }()
    
    public static func fullMultiline(context: ExecutionContext) -> [Drawable] {
        guard let moduleStore = context.moduleStores[ModuleStoreKey] else {
            return []
        }
        var multilines = moduleStore[multilineKey] ?? []
        if let turtleMultiline = moduleStore[turtleKey]?.multiline {
            multilines.append(turtleMultiline)
        }
        return multilines
    }
    
    public static func overriddenBounds(for context: ExecutionContext) -> Bounds? {
        guard let moduleStore = context.moduleStores[ModuleStoreKey] else {
            return nil
        }
        return moduleStore[boundsKey]
    }
    
    public func initialize(context: ExecutionContext) {
        let turtleStore = ExecutionContext.ModuleStore()
        context.moduleStores[Turtle.ModuleStoreKey] = turtleStore
        turtleStore[Turtle.turtleKey] = Turtle()
    }
    
    public static func multilines(for context:ExecutionContext) -> [Drawable] {
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
            case let .setPenColor(v): return "setPenColor \(v)"
            case let .setXY(point): return "setxy \(point)"
            case let .setHeading(degrees): return "setxy \(degrees)"
            case let .label(string): return "label \(string)"
            case let .bounds(bounds): return "setBounds [ \(bounds.min.x), \(bounds.min.y), \(bounds.max.x), \(bounds.max.y) ]"
            }
        }
        
        fileprivate enum Partial: String, RawRepresentable, CaseIterable, GenericProcedure {
            
            var hasRest: Bool { false }

            var description: String { self.rawValue }
            
            var name: String { self.rawValue }
            
            private static let emptyProcedure: [String:Procedure] = [:]
            
            var procedures: [String : Procedure] { Partial.emptyProcedure }
            
            func execute(context: ExecutionContext, reuseScope: Bool) throws {
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
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number.")
                    }
                    try Turtle.Command.fd(v).execute(context: context)
                case .bk:
                    guard case let .double(v) = context.variables["amount"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number.")
                    }
                    try Turtle.Command.bk(v).execute(context: context)
                case .lt:
                    guard case let .double(v) = context.variables["amount"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number.")
                    }
                    try Turtle.Command.lt(v).execute(context: context)
                case .rt:
                    guard case let .double(v) = context.variables["amount"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number.")
                    }
                    try Turtle.Command.rt(v).execute(context: context)
                case .setxy:
                    guard case let .double(x) = context.variables["x"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number for X.")
                    }
                    guard case let .double(y) = context.variables["y"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number for Y.")
                    }
                    try Turtle.Command.setXY(Point(x: x, y: y)).execute(context: context)
                case .setPenColor:
                    guard case let.list(colorValues) = context.variables["pencolor"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a list for color values.")
                    }
                    
                    let colorOut = try colorValues.map { (value) -> Double in
                        guard case let .double(v) = value else {
                            throw ExecutionHandoff.error(.typeError, "Expected a list of numbers for color values. Found \(value)")
                        }
                        return v
                    }
                    try Turtle.Command.setPenColor(colorOut).execute(context: context)
                case .setHeading:
                    guard case let .double(degrees) = context.variables["degrees"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number for degrees.")
                    }
                    try Turtle.Command.setHeading(degrees).execute(context: context)
                case .label:
                    guard case let .string(string) = context.variables["string"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a string for the argument to `label`.")
                    }
                    try Turtle.Command.label(string).execute(context: context)
                case .setBounds:
                    guard case let .double(minX) = context.variables["minX"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number for minX.")
                    }
                    guard case let .double(minY) = context.variables["minY"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number for minY.")
                    }
                    guard case let .double(maxX) = context.variables["maxX"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number for maxX.")
                    }
                    guard case let .double(maxY) = context.variables["maxY"] else {
                        throw ExecutionHandoff.error(.typeError, "\(self.rawValue) Expected a number for maxY.")
                    }
                    
                    let newBounds = Bounds(min: Point(x: minX, y: minY), max: Point(x: maxX, y: maxY))
                    
                    guard let moduleStore = context.moduleStores[ModuleStoreKey] else {
                        return
                    }
                    moduleStore[boundsKey] = newBounds
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
            case setPenColor
            case setHeading
            case label
            case setBounds
            
            var parameterCount: Int {
                switch self {
                case .fd, .bk, .rt, .lt, .setPenColor, .setHeading, .label:
                    return 1
                case .cs, .pu, .pd, .st, .ht, .home:
                    return 0
                case .setxy:
                    return 2
                case .setBounds:
                    return 4
                }
            }
            
            public var parameters: [String] {
                switch self {
                case .fd, .bk, .rt, .lt:
                    return ["amount"]
                case .setxy:
                    return ["x", "y"]
                case .setPenColor:
                    return ["pencolor"]
                case .setHeading:
                    return ["degrees"]
                case .label:
                    return ["string"]
                case .setBounds:
                    return ["minX", "minY", "maxX", "maxY"]
                case .cs, .pu, .pd, .st, .ht, .home:
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
        case setPenColor([Double])
        case setHeading(Double)
        case label(String)
        case bounds(Bounds)
        
        func execute(context: ExecutionContext) throws {
            
            guard let store = context.moduleStores[Turtle.ModuleStoreKey] else {
                throw ExecutionHandoff.error(.module, "Turtle module not initialized")
            }
            
            guard let turtle = store[turtleKey] else {
                throw ExecutionHandoff.error(.module, "Turtle not found")
            }
            
            if case .cs = self {
                store[multilineKey] = []
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
    
    public struct Segment: Drawable {
        public let start: Point
        public let end: Point
        public var color: [Double]?
    }
    
    public struct MultiLine: Drawable {
        public init(segments: [Turtle.Segment] = [], color: [Double]? = nil) {
            self.segments = segments
            self.color = color
        }
        
        mutating public func append(_ newSegment: Segment) {
            segments.append(newSegment)
        }
        
        public var segments: [Segment]
        public var color: [Double]?
    }
    
    public static let defaultAngle: Double = -90
    
    public var position: Point
    public var angle: Double
    public var pen: Pen
    public var visible: Bool
    public var multiline: MultiLine
    public var color: [Double]?
    
    public init(position: Point = .zero,
                angle: Double = Turtle.defaultAngle,
                pen: Pen = .down,
                visible: Bool = true,
                multiline: MultiLine = MultiLine()
    ) {
        self.position = position
        self.angle = angle
        self.pen = pen
        self.visible = visible
        self.multiline = multiline
    }
    
    func performing(_ command: Turtle.Command) -> Drawable? {
        switch command {
        case let .fd(dist):
            let a = angle * .pi / 180
            let newPosition = position + Point(x: cos(a) * dist, y: sin(a) * dist)
            if pen == .down {
                self.multiline.append(Segment(start: position, end: newPosition, color: self.color))
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
            angle -= a
        case let .rt(a):
            angle += a
        case .pu:
            pen = .up
            let oldML = multiline
            multiline = MultiLine()
            return oldML
        case .pd:
            pen = .down
        case .home:
            position = .zero
            angle = Turtle.defaultAngle
            let oldML = multiline
            multiline = MultiLine()
            return oldML
        case .st:
            visible = true
        case .ht:
            visible = false
        case let .setXY(position):
            self.position = position
            let oldML = multiline
            multiline = MultiLine()
            return oldML
        case .cs:
            multiline = MultiLine()
        case let .setPenColor(colorValues):
            self.color = colorValues
            break
        case let .setHeading(degrees):
            angle = degrees
        case let .label(string):
            return Label(position: self.position, angle: self.angle, text: string, color: self.color)
        case let .bounds(bounds):
            return nil
        }
        return nil
    }
}

//
//  TurtleGraphics.swift
//  Logo
//
//  Created by Fabian Canas on 10/27/18.
//  Copyright © 2018 Fabian Canas. All rights reserved.
//

import Foundation

public struct Point {
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

public struct Turtle {

    public enum Command {
        case fd(Double)
        case bk(Double)
        case lt(Double)
        case rt(Double)
        case setxy(Point)
        case pu
        case pd
        case home
        case st
        case ht
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

        case .pu, .setxy(_), .home:
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
        case let .setxy(position):
            return with(position: position, multiline: [])
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


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

    public static let defaultAngle: Double = -90

    public var position: Point = .zero
    public var angle: Double = Turtle.defaultAngle
    public var pen: Pen = .down
    public var visible: Bool = true

    public init(position: Point = .zero,
                angle: Double = Turtle.defaultAngle,
                pen: Pen = .down,
                visible: Bool = true
        ) {
        self.position = position
        self.angle = angle
        self.pen = pen
        self.visible = visible
    }

    func with(position: Point? = nil,
              angle: Double? = nil,
              pen: Pen? = nil,
              visible: Bool? = nil
        ) -> Turtle {
        return Turtle(position: position ?? self.position,
                      angle: angle ?? self.angle,
                      pen: pen ?? self.pen,
                      visible: visible ?? self.visible
        )
    }

    func performing(_ command: Turtle.Command) -> (Turtle, Segment?) {
        let out = with(command)
        let segment: Segment?

        switch command {

        case .fd(_) where self.pen == .down, .bk(_)  where self.pen == .down:
            segment = Segment(start: position, end: out.position)
        default:
            segment = nil
        }

        return (out, segment)
    }

    func with(_ command: Turtle.Command) -> Turtle {
        switch command {
        case let .fd(dist):
            let a = angle * .pi / 180
            return with(position: position + Point(x: cos(a) * dist, y: sin(a) * dist))
        case let .bk(dist):
            let a = angle * .pi / 180
            return with(position: position - Point(x: cos(a) * dist, y: sin(a) * dist))
        case let .lt(a):
            return with(angle: angle + a)
        case let .rt(a):
            return with(angle: angle - a)
        case .pu:
            return with(pen: .up)
        case .pd:
            return with(pen: .down)
        case .home:
            return with(position:.zero, angle: Turtle.defaultAngle)
        case .st:
            return with(visible: true)
        case .ht:
            return with(visible: false)
        case let .setxy(position):
            return with(position: position)
        }
    }
}

public struct Canvas {
    public let turtle: Turtle
    public let segments: [Turtle.Segment]

    public init(turtle: Turtle, segments: [Turtle.Segment] = []) {
        self.turtle = turtle
        self.segments = segments
    }

    public func performing(_ command: Turtle.Command) -> Canvas {
        let (t, s) = turtle.performing(command)
        return Canvas(turtle: t, segments: s.map { self.segments + [$0] } ?? segments )
    }
}

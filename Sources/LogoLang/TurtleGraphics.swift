//
//  TurtleGraphics.swift
//  Logo
//
//  Created by Fabian Canas on 10/27/18.
//  Copyright © 2018 Fabian Canas. All rights reserved.
//

#if os(macOS)
import Quartz
#elseif os(iOS)
import QuartzCore
#endif

extension CGPoint {
    static func + (_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}

#if os(iOS)
import UIKit
extension CGColor {
    static var white = UIColor.white.cgColor
}
#endif

public struct Turtle {

    public enum Command {
        case fd(CGFloat)
        case bk(CGFloat)
        case lt(CGFloat)
        case rt(CGFloat)
        case setxy(CGPoint)
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
        public let start: CGPoint
        public let end: CGPoint
        public let color: CGColor
    }

    public static let defaultAngle: CGFloat = -90

    public var position: CGPoint = .zero
    public var angle: CGFloat = Turtle.defaultAngle
    public var pen: Pen = .down
    public var visible: Bool = true
    private var color: CGColor = CGColor.white

    public init(position: CGPoint = .zero,
                 angle: CGFloat = Turtle.defaultAngle,
                 pen: Pen = .down,
                 visible: Bool = true
        ) {
        self.init(position: position, angle: angle, pen: pen, visible: visible, color: CGColor.white)
    }

    private init(position: CGPoint,
                angle: CGFloat,
                pen: Pen,
                visible: Bool,
                color: CGColor
        ) {
        self.position = position
        self.angle = angle
        self.pen = pen
        self.visible = visible
        self.color = color
    }

    func with(position: CGPoint? = nil,
              angle: CGFloat? = nil,
              pen: Pen? = nil,
              visible: Bool? = nil,
              color: CGColor? = nil
        ) -> Turtle {
        return Turtle(position: position ?? self.position,
                      angle: angle ?? self.angle,
                      pen: pen ?? self.pen,
                      visible: visible ?? self.visible,
                      color: color ?? self.color
        )
    }

    func performing(_ command: Turtle.Command) -> (Turtle, Segment?) {
        let out = with(command)
        let segment: Segment?

        switch command {

        case .fd(_) where self.pen == .down, .bk(_)  where self.pen == .down:
            segment = Segment(start: position, end: out.position, color: color)
        default:
            segment = nil
        }

        return (out, segment)
    }

    func with(_ command: Turtle.Command) -> Turtle {
        switch command {
        case let .fd(dist):
            let a = angle * .pi / 180
            return with(position: position + CGPoint(x: cos(a) * dist, y: sin(a) * dist))
        case let .bk(dist):
            let a = angle * .pi / 180
            return with(position: position - CGPoint(x: cos(a) * dist, y: sin(a) * dist))
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

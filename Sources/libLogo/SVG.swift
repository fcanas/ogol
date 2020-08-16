//
//  SVGOutput.swift
//  FFCParserCombinator
//
//  Created by Fabian Canas on 5/3/20.
//

import Execution
import Foundation
import LogoLang

enum SVGError: Error {
    case emptyMultiLine
}

struct Bounds {
    var min: Point
    var max: Point
    
    func extend(point: Point) -> Bounds {
        return Bounds(min: Point(x: Swift.min(min.x, point.x), y: Swift.min(min.y, point.y)), max: Point(x: Swift.max(max.x, point.x), y: Swift.max(max.y, point.y)))
    }
    
    func extend(bounds: Bounds) -> Bounds {
        return Bounds(min: Point(x: Swift.min(min.x, bounds.min.x), y: Swift.min(min.y, bounds.min.y)), max: Point(x: Swift.max(max.x, bounds.max.x), y: Swift.max(max.y, bounds.max.y)))
    }
}

func bounds(_ a: Point, _ b: Point) -> Bounds {
    return Bounds(min: Point(x: min(a.x, b.x), y: min(a.y, b.y)), max: Point(x: max(a.x, b.x), y: max(a.y, b.y)))
}

protocol SVGEncodable {
    func element(translate: Point) throws -> Tag
    func bounds() -> Bounds?
}

struct Tag {
    let name: String
    let properties: [String:String]
    func asXML() -> String {
        var stringOut = "<" + name
        for (k,v) in properties {
            stringOut += " \(k)=\"\(v)\""
        }
        return stringOut + "/>"
    }
}

extension Turtle.MultiLine: SVGEncodable {
    func bounds() -> Bounds? {
        guard let firstSegment = first else {
            return nil
        }
        
        return reduce(Bounds(min: firstSegment.start, max: firstSegment.start)) { (bounds, segment) -> Bounds in
            return bounds.extend(point: segment.start).extend(point: segment.end)
        }
    }
    
    func element(translate: Point) throws -> Tag {
        guard let firstSegment = first else {
            throw SVGError.emptyMultiLine
        }
        
        func stringify(point: Point) -> String {
            return "\(point.x + translate.x), \(point.y + translate.y)"
        }
        
        let points = reduce(stringify(point: firstSegment.start)) { (result, segment) -> String in
            return result + " " + stringify(point: segment.end)
        }
        
        return Tag(name: "polyline", properties: ["points":points, "fill":"none", "stroke-width":"1px"])
    }
}

public class SVGEncoder {
    
    public init() {}
    
    public func encode(context: ExecutionContext) throws -> String {
        return try encode(Turtle.fullMultiline(context: context))
    }
    
    public func encode(program: Program) throws -> String {
        let context: ExecutionContext = ExecutionContext()
        context.load(Turtle())
        context.load(Meta())

        try program.execute(context: context, reuseScope: false)

        let multiLines = Turtle.multilines(for: context)
        
        return try encode(multiLines)
    }
    
    public func encode(_ items: [Turtle.MultiLine]) throws -> String { // formerly accepted SVGEncodable
        
        let bounds = items.reduce(Bounds(min: Point.zero, max: .zero)) { (bounds, encodable) -> Bounds in
            return encodable.bounds().map {bounds.extend(bounds: $0)} ?? bounds
        }
        
        let width = max(abs(ceil(bounds.max.x)), abs(floor(bounds.min.x))) * 2 + 20
        let height = max(abs(ceil(bounds.max.y)), abs(floor(bounds.min.y))) * 2 + 20
        
        let translation = Point(x: -width / 2, y: height / 2)
        
        var output =
        "<svg version=\"1.1\" baseProfile=\"full\" width=\"\(Int(width))\" height=\"\(Int(height))\" xmlns=\"http://www.w3.org/2000/svg\">"
        output += "\n<g transform=\"scale(-1, 1)\">"
        output += items.compactMap({ try? $0.element(translate: translation).asXML() }).joined(separator: "\n")
        output += "\n</g>\n"
        return output + "</svg>"
    }
}

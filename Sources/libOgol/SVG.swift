//
//  SVGOutput.swift
//  OgoLang.libOgol
//
//  Created by Fabian Canas on 5/3/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Execution
import Foundation
import OgoLang

enum SVGError: Error {
    case emptyMultiLine
}

public struct Bounds {
    var min: Point
    var max: Point
    
    func extend(point: Point) -> Bounds {
        return Bounds(min: Point(x: Swift.min(min.x, point.x), y: Swift.min(min.y, point.y)), max: Point(x: Swift.max(max.x, point.x), y: Swift.max(max.y, point.y)))
    }
    
    func extend(bounds: Bounds) -> Bounds {
        return Bounds(min: Point(x: Swift.min(min.x, bounds.min.x), y: Swift.min(min.y, bounds.min.y)), max: Point(x: Swift.max(max.x, bounds.max.x), y: Swift.max(max.y, bounds.max.y)))
    }
    
    var width: Double {
        return max.x - min.x
    }
    var height: Double {
        return max.y - min.y
    }
}

func bounds(_ a: Point, _ b: Point) -> Bounds {
    return Bounds(min: Point(x: min(a.x, b.x), y: min(a.y, b.y)), max: Point(x: max(a.x, b.x), y: max(a.y, b.y)))
}

public protocol SVGEncodable: Drawable {
    func element(translate: Point, properties: [String:String]) throws -> Tag
    func bounds() -> Bounds?
}

public struct Tag {
    let name: String
    let properties: [String:String]
    let content: String?
    func asXML() -> String {
        var stringOut = "<" + name
        let keys = properties.keys.sorted()
        for k in keys {
            stringOut += " \(k)=\"\(properties[k]!)\""
        }
        if let c = content, !c.isEmpty {
            return "\(stringOut)>\(c)</\(name)>"
        } else {
            return stringOut + "/>"
        }
    }
}

extension Label: SVGEncodable {
    public func element(translate: Point, properties: [String : String]) throws -> Tag {
        let position = self.position + translate
        var properties = [
            "x":String(position.x),
            "y":String(position.y),
            "transform":"rotate(\(self.angle)) translate(\(position.x),\(position.y)) translate(\(-position.x),\(-position.y))",
            "stroke" : "none",
        ]
        if let c = self.color {
            properties["fill"] = ColorVecAsString(c)
        }
        return Tag(name: "text", properties: properties, content: self.text)
    }
    
    public func bounds() -> Bounds? {
        nil
    }
    
}

func ColorVecAsString(_ cVec: [Double]) -> String {
    "rgb(\( cVec.map({String($0)}).joined(separator: ",") ))"
}

extension Turtle.MultiLine: SVGEncodable {
    public func bounds() -> Bounds? {
        guard let firstSegment = segments.first else {
            return nil
        }
        
        return segments.reduce(Bounds(min: firstSegment.start, max: firstSegment.start)) { (bounds, segment) -> Bounds in
            return bounds.extend(point: segment.start).extend(point: segment.end)
        }
    }
    
    public func element(translate: Point, properties: [String:String]) throws -> Tag {
        guard let firstSegment = segments.first else {
            throw SVGError.emptyMultiLine
        }
        
        func stringify(point: Point) -> String {
            return "\(point.x + translate.x), \(point.y + translate.y)"
        }
        
        let r = segments.reduce((stringify(point: firstSegment.start), nil)) { (result, segment) -> (String,String?) in
            return (result.0 + " " + stringify(point: segment.end), segment.color.map( ColorVecAsString ) ?? result.1 )
        }
        
        var p = properties.merging(["points":r.0, "fill":"none", "stroke-width":"1px"], uniquingKeysWith: { (a,_) in a })
        if let color = r.1 {
            p["stroke"] = color
        }
        return Tag(name: "polyline", properties: p, content: nil)
    }
}

public class SVGEncoder {
    
    public init() {}
    
    public func encode(context: ExecutionContext) throws -> String {
        return try encode(Turtle.fullMultiline(context: context).compactMap( { $0 as? SVGEncodable } ), bounds: Turtle.overriddenBounds(for: context) )
    }
    
    public func encode(program: Program) throws -> String {
        let context: ExecutionContext = ExecutionContext()
        context.load(Turtle())
        context.load(Meta())

        try program.execute(context: context, reuseScope: false)

        let multiLines = Turtle.multilines(for: context).compactMap( { $0 as? SVGEncodable } )
        
        return try encode(multiLines)
    }
    
    public func encode(_ items: [SVGEncodable], bounds boundsIn: Bounds? = nil, margin: Double = 20) throws -> String { // formerly accepted SVGEncodable
        
        let bounds: Bounds
        
        bounds = boundsIn ?? items.reduce(Bounds(min: Point.zero, max: .zero)) { (bounds, encodable) -> Bounds in
            return encodable.bounds().map {bounds.extend(bounds: $0)} ?? bounds
        }
        
        let translation = Point.zero
        
        return """
        <svg version="1.1" baseProfile="full" width="\(Int(bounds.width + 2 * margin))" height="\(Int(bounds.height + 2*margin))" viewBox="\(bounds.min.x - margin) \(bounds.min.y - margin) \(bounds.width + 2 * margin) \(bounds.height + 2 * margin)" xmlns="http://www.w3.org/2000/svg">
        <g style="overflow=visible;">
        \(items.compactMap({ try? $0.element(translate: translation, properties: [:]).asXML() }).joined(separator: "\n"))
        </g>
        </svg>
        """
    }
}

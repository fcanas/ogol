//
//  ViewController.swift
//  exLogo
//
//  Created by Fabian Canas on 6/4/20.
//

import Cocoa

import LogoLang
import libLogo

extension NSColor {
    func webString() -> String {
        func _private(_ c: NSColor) -> String {
            return "rgb(\(ceil(c.redComponent * 255)),\(ceil(c.greenComponent * 255)),\(ceil(c.blueComponent * 255)))"
        }
        return usingColorSpace(.displayP3).map(_private) ?? ""
    }
}

class ViewController: NSViewController {
    
    @IBOutlet var textField: NSTextField!
    @IBOutlet var outputView: NSTextView!
    @IBOutlet var webRenderController: SVGRenderController!
    
    var appearanceOvserver: NSKeyValueObservation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        CLI.message = { [weak self] in self?.push(message: $0) }
        CLI.clear = { [weak self] in self?.outputView?.string = "" }
        appearanceOvserver = view.observe(\.effectiveAppearance) { [weak self] (_, _) in
            self?.updateAppearance()
        }
    }
    
    func updateAppearance() {
        switch view.effectiveAppearance.name {
        case NSAppearance.Name.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark:
            webRenderController.canvasBackgroundColor = NSColor.black.webString()
            webRenderController.svgStrokeColor = "white"
        case NSAppearance.Name.aqua, .vibrantLight, .accessibilityHighContrastAqua, .accessibilityHighContrastVibrantLight:
            webRenderController.canvasBackgroundColor = NSColor.white.webString()
            webRenderController.svgStrokeColor = "black"
        default:
            break
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    let parser: LogoParser = {
        let p = LogoParser()
        p.modules = [Turtle.self, LogoMath.self, CLI.self]
        return p
    }()
    
    @IBAction func handleInput(sender: NSTextField) {
        let command = sender.stringValue
        sender.stringValue = ""
        push(message: command)
        
        let substring = Substring(command)
        let result = parser.program(substring: substring)
        switch result {
        case let .success(program, _, e):
            if e.count > 0 { push(message: "error \(e)") }
            execute(program)
        case let .error(errorMap):
            showError(errorMap, substring: substring)
        }
    }
    
    func showError(_ errorMap: [Range<Substring.Index> : LogoParser.ParseError], substring: Substring) {
        push(message: "\(errorMap.count) errors")
    }
    
    func push(message: String) {
        guard let textView = outputView else {
            return
        }
        var s = textView.string
        s += "\n" + message
        textView.string = s
        textView.scrollRangeToVisible(NSRange(location: Int.max, length: 1))
    }
    
    var executionContext: ExecutionContext = {
        let e = ExecutionContext()
        e.load(LogoMath.self)
        e.load(Turtle.self)
        e.load(CLI.self)
        return e
    }()
    
    func execute(_ program: Program) {
        do {
            try program.execute(context: executionContext, reuseScope: true)
            
            program.procedures.forEach { (key: String, value: Procedure) in
                executionContext.procedures[key] = value
                parser.additionalProcedures[key] = value
            }
            
            let svg = try SVGEncoder().encode(context: executionContext)
            
            webRenderController.render(svg: svg)
        } catch let e {
            let alert = NSAlert(error: e)
            alert.runModal()
        }
    }
}

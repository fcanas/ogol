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
    @IBOutlet var statusController: StatusController!
    
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
    
    func accept(command: String) {
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
    
    let workQ = DispatchQueue(label: "logo.q", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    
    func execute(_ program: Program) {
        
        let executionContext = self.executionContext
        let parser = self.parser
        let webRenderController = self.webRenderController!
        let statusController = self.statusController!
        
        var svg: String?
        var err: Error?
        
        statusController.state = .running
        
        let executeProgram = DispatchWorkItem {
            do {
                try program.execute(context: executionContext, reuseScope: true)
                
                program.procedures.forEach { (key: String, value: Procedure) in
                    executionContext.procedures[key] = value
                    parser.additionalProcedures[key] = value
                }
                
                svg = try SVGEncoder().encode(context: executionContext)
            } catch let e {
                err = e
            }
        }
        executeProgram.notify(queue: .main) {
            if let svg = svg {
                webRenderController.render(svg: svg)
                statusController.state = .idle
            } else if let err = err {
                let alert = NSAlert(error: err)
                alert.runModal()
                statusController.state = .error
            }
        }
        workQ.async(execute: executeProgram)
    }
}

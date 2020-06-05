//
//  SVGRenderController.swift
//  exLogo
//
//  Created by Fabian Canas on 6/5/20.
//

import Foundation
import WebKit

class SVGRenderController: NSObject {
    
    @IBOutlet var webView: WKWebView?
    
    var svgStrokeColor: String = "black"
    var canvasBackgroundColor: String = "white"
    
    func render(svg: String) {
        guard let webView = webView else {
            return
        }
        
        do {
        let temporaryDirectoryURL =
        try FileManager.default.url(for: .cachesDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
        let temporaryFilename = ProcessInfo().globallyUniqueString
        let temporaryFileURL =
            temporaryDirectoryURL.appendingPathComponent(temporaryFilename).appendingPathExtension("html")
        let html = """
            <html>
            <style rel="stylesheet" type="text/css">
              body {
                display: flex;
                align-items: center;
                justify-content: center;
                overflow: visible;
                background: \(canvasBackgroundColor);
              }
              svg {
                stroke: \(svgStrokeColor);
                overflow: visible;
              }
            </style>
            <body>
            \(svg)
            </body>
            </html>
        """
        
        try html.data(using: .utf8)?.write(to: temporaryFileURL)
        webView.loadFileURL(temporaryFileURL, allowingReadAccessTo: temporaryDirectoryURL)
        } catch let e {
            let alert = NSAlert(error: e)
            alert.runModal()
        }
    }
}

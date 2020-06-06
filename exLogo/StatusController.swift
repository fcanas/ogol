//
//  StatusController.swift
//  exLogo
//
//  Created by Fabian Canas on 6/5/20.
//

import AppKit
import Foundation


class StatusController: NSObject {
    @IBOutlet var statusLabel: NSTextField!
    @IBOutlet var activityIndicator: NSProgressIndicator!
    @IBOutlet var stackDepthIndicator: NSProgressIndicator!
    
    enum State {
        case idle
        case error
        case executing(UInt)
        case render
    }
    
    var maxStackDepth: UInt = 1
    
    override func awakeFromNib() {
        super.awakeFromNib()
        activityIndicator.isDisplayedWhenStopped = false
    }
    
    var state: State = .idle {
        didSet {
            DispatchQueue.main.async {
                switch self.state {
                case .idle:
                    self.activityIndicator.stopAnimation(self)
                    self.statusLabel.stringValue = ""
                    self.stackDepthIndicator.isHidden = true
                case let .executing(depth):
                    self.activityIndicator.startAnimation(self)
                    self.statusLabel.stringValue = "executing..."
                    self.stackDepthIndicator.startAnimation(self)
                    self.stackDepthIndicator.isHidden = false
                    self.stackDepthIndicator.doubleValue = self.stackDepthIndicator.maxValue * Double(depth) / Double(self.maxStackDepth)
                case .render:
                    self.activityIndicator.startAnimation(self)
                    self.statusLabel.stringValue = "rendering..."
                    self.stackDepthIndicator.isHidden = true
                case .error:
                    self.activityIndicator.stopAnimation(self)
                    self.statusLabel.stringValue = "error"
                }
            }
        }
    }
    
}

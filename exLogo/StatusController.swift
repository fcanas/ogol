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
    
    enum State {
        case idle
        case error
        case running
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        activityIndicator.isDisplayedWhenStopped = false
    }
    
    var state: State = .idle {
        didSet {
            switch state {
            case .idle:
                activityIndicator.stopAnimation(self)
                statusLabel.stringValue = ""
            case .running:
                activityIndicator.startAnimation(self)
                statusLabel.stringValue = "running..."
            case .error:
                activityIndicator.stopAnimation(self)
                statusLabel.stringValue = "error"
            }
        }
    }
    
}

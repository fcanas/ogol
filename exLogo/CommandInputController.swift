//
//  CommandInputController.swift
//  exLogo
//
//  Created by Fabian Canas on 6/5/20.
//

import AppKit
import Foundation

class CommandInputController: NSObject, NSTextFieldDelegate {
    
    @IBOutlet var textField: NSTextField!
    @IBOutlet var execution: ViewController!
    
    var commandHistory: [String] = []
    var idx: Int?
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSTextView.moveUp(_:)) {
            if commandHistory.count == 0 {
                return false
            }
            if idx == nil {
                idx = 0
            } else if idx! + 1 < commandHistory.count {
                idx! += 1
            }
            
            textField.stringValue = commandHistory[idx!]
            
            return true
        } else if commandSelector == #selector(NSTextView.moveDown(_:)) {
            if commandHistory.count == 0 {
                return false
            }
            if idx == nil {
                return false
            }
            if idx == 0 {
                return false
            }
            idx! -= 1
            textField.stringValue = commandHistory[idx!]
            return true
        } else if commandSelector == #selector(NSTextView.insertNewline(_:)) {
            submit(textField)
            return true
        } else if commandSelector == #selector(NSTextView.insertNewlineIgnoringFieldEditor(_:)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(106)) {
                self.textField.invalidateIntrinsicContentSize()
                self.textField.needsUpdateConstraints = true
                self.textField.sizeToFit()
                self.textField.superview?.needsLayout = true
            }
            return false
        }
        
        return false
    }
    
    func submit(_ sender: NSTextField) {
        let command = sender.stringValue
        sender.stringValue = ""
        commandHistory = [command] + commandHistory
        idx = nil
        
        execution.accept(command: command)
    }
    
}

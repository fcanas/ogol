//
//  File.swift
//  
//
//  Created by Fabian Canas on 7/22/20.
//

import LogoLang
import Foundation

public let CoreLib: NativeModule? = {
    guard let url = Bundle.module.url(forResource: "CoreLib", withExtension: "logo"), let string = try? String(contentsOf: url) else {
        return nil
    }
    return NativeModule(string: string)
}()


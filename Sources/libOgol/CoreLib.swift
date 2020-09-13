//
//  CoreLib.swift
//  OgoLang.libOgol
//
//  Created by Fabian Canas on 7/22/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import Foundation
import OgoLang
import ToolingSupport

public let CoreLib: NativeModule? = {
    guard let url = Bundle.module.url(forResource: "CoreLib", withExtension: "logo"), let string = try? String(contentsOf: url) else {
        return nil
    }
    return NativeModule(string: string, parser: OgolParser())
}()


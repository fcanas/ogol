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
    guard let url = Bundle.module.url(forResource: "CoreLib", withExtension: "ogol"), let string = try? String(contentsOf: url) else {
        return nil
    }
    let parser = OgolParser()
    parser.modules = [Meta()]
    return NativeModule(string: string, parser: parser) { context in
        context.variables.setLocal(key: "true", item: .boolean(true))
        context.variables.setLocal(key: "false", item: .boolean(false))
    }
}()

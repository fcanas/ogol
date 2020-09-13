//
//  CLI.swift
//  ogol
//
//  Created by Fabián Cañas on 5/17/20.
//  Copyright © 2020 Fabian Canas. All rights reserved.
//

import libOgol
import OgoLang
import ToolingSupport
import Execution

let modules: [Module] = [CLI(),
                         LogoMath(),
                         Turtle(),
                         Serialization(),
                         Optimizer(),
                         Meta(),
                         CoreLib!]

startRepl(parser: OgolParser(), modules: modules)

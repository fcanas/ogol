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

let CoreLibString =
"""
;
;  CoreLib.logo
;  OgoLang.libOgol
;
;  Created by Fabian Canas on 7/22/20.
;  Copyright © 2020 Fabian Canas. All rights reserved.
;

to list [[:elements]]
   output[elements]
end

to add [:lhs, :rhs]
   output[lhs + rhs]
end

to sub [:lhs, :rhs]
   output[lhs - rhs]
end

to mul [:lhs, :rhs]
   output[lhs * rhs]
end

to div [:lhs, :rhs]
   output[lhs / rhs]
end

to repeat [:count, :instructionList]
   if [count < 1, [stop[]]]
   run [instructionList]
   repeat [count - 1, instructionList]
end

to empty [:empList]
    local[:c, count[empList]]
    output[ c < 1 ]
end

to map0 [:remainingItems]
    if [ empty [remainingItems], [ stop[] ]]
    append [ invoke [proc, item [ 0, remainingItems ] ] , :mapOut ]
    map0 [ butFirst [ remainingItems ] ]
end

to map [:proc, :itemList]
    local [:mapOut, list[]]
    map0 [itemList]
    output [ mapOut ]
end

to forEach [:proc, :data]
    local[:dataIndex, 0]
    repeat[count[data], [
        invoke[proc, item[dataIndex, data]]
        make[:dataIndex, dataIndex + 1]
    ]]
end

to radToDeg[:rad]
   output [ rad * 360 / tau ]
end

to arc[:radius, :radians]
    local[:remainingDistance, tau * radius / radians]
    local[:numberOfSteps, remainingDistance]
    local[:degrees, radToDeg[radians]]
    repeat[numberOfSteps, [
        fd [1]
        rt [degrees / numberOfSteps]
    ]]
end

"""

public let CoreLib: NativeModule? = {
    
    let parser = OgolParser()
    parser.modules = [Meta()]
    return NativeModule(string: CoreLibString, parser: parser) { context in
        context.variables.setLocal(key: "true", item: .boolean(true))
        context.variables.setLocal(key: "false", item: .boolean(false))
    }
}()

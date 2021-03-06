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

to List [[:elements]]
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
    local[:c, List.count[empList]]
    output[ c < 1 ]
end

to _map [:remainingItems]
    if [ empty [remainingItems], [ stop[] ]]
    List.append [ invoke [proc, List.item [ 0, remainingItems ] ] , :mapOut ]
    _map [ butFirst [ remainingItems ] ]
end

to map [:proc, :itemList]
    local [:mapOut, list[]]
    _map [itemList]
    output [ mapOut ]
end

to forEach [:proc, :data]
    local[:dataIndex, 0]
    repeat[List.count[data], [
        invoke[proc, List.item[dataIndex, data]]
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

; List

to List.multiIndex[:listIn, [:idx]]
    local[:valueOut, 0]
    _List.multiIndex[listIn, idx]
    output[valueOut]
end

to _List.multiIndex[:listIn, :idx]
    local [ :listCount, List.count [idx] ]
    if [ listCount = 0, [
        make [ :valueOut, listIn ]
        stop[]
    ]]
    _List.multiIndex [ List.item [ List.item [0, idx], listIn ], List.butFirst [idx] ]
end

to min[:a, :b]
    if [ a > b, [ output[b]]];
    output[a]
end

to max[:a, :b]
    if [ a < b, [ output[b]]]
    output[a]
end

to tick[]
    make[:_Time.startTime, Time.now[]]
end

to tock[]
    local[:elapsedTime, Time.now[]]
    output[elapsedTime - _Time.startTime]
end

"""

public let CoreLib: NativeModule? = {
    
    let parser = OgolParser()
    parser.modules = [Meta()]
    return NativeModule(string: CoreLibString, parser: parser) { context in
        context.variables.setLocal(key: "true", item: .boolean(true))
        context.variables.setLocal(key: "false", item: .boolean(false))
        context.variables.setLocal(key: "_Time.startTime", item: .double(0))
    }
}()

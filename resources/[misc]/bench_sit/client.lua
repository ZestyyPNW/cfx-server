local benchModel = `v_ilev_ph_bench`

local function sitOnBench(data)
    local ped = PlayerPedId()
    if IsPedUsingScenario(ped) then
        ClearPedTasks(ped)
        return
    end

    local entity = data and data.entity or 0
    if entity == 0 or not DoesEntityExist(entity) then return end

    local coords = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, 0.5)
    local heading = GetEntityHeading(entity)

    TaskStartScenarioAtPosition(ped, 'PROP_HUMAN_SEAT_BENCH', coords.x, coords.y, coords.z, heading, 0, true, true)
end

exports.ox_target:addModel(benchModel, {
    {
        name = 'bench_sit',
        icon = 'fa-solid fa-chair',
        label = 'Sit',
        distance = 1.5,
        onSelect = sitOnBench
    }
})

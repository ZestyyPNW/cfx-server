Config = {
    label = 'Repair vehicle',
    icon = 'fa-solid fa-screwdriver-wrench',
    distance = 2.0,
    bones = { 'bonnet', 'engine' },
    minEngineHealth = 400.0,
    repairDuration = 8000,
    progressLabel = 'Repairing vehicle',
    progressPosition = 'bottom',
    fullEngineHealth = 1000.0,
    fullBodyHealth = 1000.0,
    fullPetrolHealth = 1000.0,
    successMessage = 'Vehicle repaired.',
    openDoors = { 4 },
    repairOffset = { x = 0.0, y = 2.5, z = 0.0 },
    approachDistance = 1.0,
    approachTimeout = 3000,
    repairAnim = {
        dict = 'mini@repair',
        clip = 'fixing_a_ped'
    },
    repairScenario = 'WORLD_HUMAN_VEHICLE_MECHANIC',
    prop = {
        model = `prop_tool_wrench`,
        pos = { x = 0.12, y = 0.02, z = 0.0 },
        rot = { x = 90.0, y = 0.0, z = 10.0 }
    }
}

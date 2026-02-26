-- Sheriff NPC Configuration
-- Patrol vehicles available from combined-leo

SheriffNPC = {
    -- Sheriff NPC location (updated to your exact coordinates)
    {
        coords = vec4(382.89, -1611.88, 29.29, 230.63), -- x, y, z, heading
        model = "s_m_y_sheriff_01", -- Sheriff ped model
        animation = {
            dict = "amb@world_human_cop_idles@male@base",
            anim = "base"
        }
    }
}

-- Available patrol vehicles from combined-leo
PatrolVehicles = {
    {
        label = "LASD Tahoe 2015",
        model = "lasd15tahoe",
        livery = 0,
        extraLiveries = {0, 1, 2}
    },
    {
        label = "LASD Charger 2020",
        model = "lasd20tahoe",
        livery = 0,
        extraLiveries = {0, 1, 2}
    },
    {
        label = "LASD Crown Victoria",
        model = "lasdcrownvic",
        livery = 0,
        extraLiveries = {0, 1, 2}
    },
    {
        label = "LASD CVPI Carson",
        model = "lasd06cvpicarson",
        livery = 0,
        extraLiveries = {0, 1, 2}
    },
    {
        label = "LASD CVPI 2005",
        model = "lasd05cvpi",
        livery = 0,
        extraLiveries = {0, 1, 2}
    },
    {
        label = "LASD Ford Explorer",
        model = "lasdparamount",
        livery = 0,
        extraLiveries = {0, 1, 2}
    },
    {
        label = "LASD Dodge Charger",
        model = "lasd13fasap",
        livery = 0,
        extraLiveries = {0, 1, 2}
    }
}

-- Vehicle spawn locations
VehicleSpawnLocations = {
    {
        coords = vec4(388.75, -1612.55, 29.29, 228.81),
        radius = 5.0
    },
    {
        coords = vec4(390.71, -1610.46, 29.29, 230.64),
        radius = 5.0
    },
    {
        coords = vec4(329.63, -1607.97, 29.29, 228.48),
        radius = 5.0
    },
    {
        coords = vec4(403.37, -1616.47, 29.29, 140.02),
        radius = 5.0
    }
}

-- Who can access the vehicle spawner
AllowedJobs = {
    "lasd"
}
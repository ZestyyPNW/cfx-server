Config = {}

-- Web MDC Configuration
-- Using localhost since FiveM and web server are on same machine
Config.MDC_URL = "http://127.0.0.1:3000/api/imperialcad/sync-call"
Config.MDC_API_KEY = "7ad6d1695fec1b36d4769e1c7bb6420a4eabf6dfde7ec82aef77df932aac6803"

-- Debug mode (set to false in production)
Config.Debug = true

-- Call sync settings
Config.SyncInterval = 30000 -- Check for call updates every 30 seconds (30000ms)
Config.AutoSync = true -- Automatically sync calls to MDC

-- Radio code mappings (ImperialCAD nature -> LASD radio codes)
Config.RadioCodes = {
    ["Disturbance"] = "415",
    ["Assault"] = "245",
    ["Assault With Deadly Weapon"] = "245",
    ["Robbery"] = "211",
    ["Shooting"] = "417 245",
    ["Traffic Stop"] = "510",
    ["Vehicle Pursuit"] = "510",
    ["Suspicious Person"] = "925A",
    ["Trespassing"] = "602N",
    ["Hit and Run"] = "481R 20002",
    ["Theft"] = "484",
    ["Burglary"] = "459",
    ["Domestic Violence"] = "415 273.5",
    ["Welfare Check"] = "10-21",
    ["Person With Gun"] = "417",
    ["Person With Knife"] = "417",
    ["Medical"] = "10-52",
    ["Fire"] = "10-70",
    ["Traffic Collision"] = "11-80",
    ["Unknown"] = "11-99" -- Catch-all for unknown call types
}

-- Priority mappings
Config.PriorityMap = {
    [1] = "PRIORITY 1", -- Life-threatening
    [2] = "PRIORITY 2", -- Urgent but not life-threatening
    [3] = "PRIORITY 3", -- Routine
    [4] = "PRIORITY 4", -- Low priority
}

-- Status code mappings (ImperialCAD -> LASD)
Config.StatusMap = {
    ["PENDING"] = "(D)",
    ["DISPATCHED"] = "(D)",
    ["ENROUTE"] = "ENR",
    ["ON_SCENE"] = "10-97",
    ["CLEARED"] = "CLR",
    ["AVAILABLE"] = "10-8"
}

Config = {}

-- ============================================================
-- DRUG DEFINITIONS
--
-- rawItem      → consumed at the grow/source zone to start the chain
-- harvestItem  → received after grow/source step
-- processItem  → received after processing harvestItem
--               (if == harvestItem the process zone is skipped)
-- productItem  → final sellable bag, produced from processItem
--
-- qualities    → weed only; each entry is an alternate seed item with
--               its own yield range.  Server picks whichever one the
--               player is carrying.
--
-- packageSupplies → list of {item, count} consumed at the PACKAGE step
-- ============================================================
Config.Drugs = {
    weed = {
        label       = 'Weed',
        -- Three quality tiers — server checks which seed the player has
        qualities = {
            { item = 'weed_seed1', label = 'Schwag', yieldMin = 2,  yieldMax = 4  },
            { item = 'weed_seed',  label = 'Mid',    yieldMin = 4,  yieldMax = 7  },
            { item = 'weed_seed3', label = 'Loud',   yieldMin = 7,  yieldMax = 12 },
        },
        rawItem      = 'weed_seed',       -- fallback / display
        harvestItem  = 'weed_og_kush_bud',
        processItem  = 'ground_weed',
        productItem  = 'baggy_weed',
        packageSupplies = {},
        growTime     = 45,
        processTime  = 30,
        packageTime  = 20,
        sellPriceBase = 80,
        sellVariance  = 0.15,
        effect        = 'weed',
    },
    meth = {
        label        = 'Meth',
        rawItem      = 'methalmine2',
        harvestItem  = 'meth_tray',
        processItem  = 'meth_tray',
        productItem  = 'baggy_meth',
        packageSupplies = {},             -- methalmine2 IS consumed at grow step
        growTime     = 60,
        processTime  = 50,
        packageTime  = 25,
        yieldMin     = 2,
        yieldMax     = 5,
        sellPriceBase = 260,
        sellVariance  = 0.15,
        effect        = 'meth',
    },
    cocaine = {
        label        = 'Cocaine',
        rawItem      = 'cocaineleaf',
        harvestItem  = 'cocaine_cut',
        processItem  = 'cocaine_cut',
        productItem  = 'baggy_cocaine',
        packageSupplies = {
            { item = 'babypowder', count = 1 },   -- cutting agent consumed when bagging
        },
        growTime     = 50,
        processTime  = 40,
        packageTime  = 25,
        yieldMin     = 2,
        yieldMax     = 5,
        sellPriceBase = 320,
        sellVariance  = 0.15,
        effect        = 'cocaine',
    },
    heroin = {
        label        = 'Heroin',
        rawItem      = 'drug_opium',
        harvestItem  = 'drug_heroin',
        processItem  = 'drug_heroin',
        productItem  = '1gheroin',
        packageSupplies = {
            { item = 'hydroxyphosphate', count = 1 },  -- acetylation chemicals consumed when bagging
        },
        growTime     = 55,
        processTime  = 45,
        packageTime  = 25,
        yieldMin     = 2,
        yieldMax     = 4,
        sellPriceBase = 440,
        sellVariance  = 0.15,
        effect        = 'heroin',
    },
}

-- ============================================================
-- ZONE LOCATIONS
-- grow[] → source/grow interaction
-- process[] → process + package interaction (same zone, two options)
-- ============================================================
Config.Zones = {
    weed = {
        grow = {
            { coords = vector3(2043.4, 4941.4, 41.0), radius = 26.6, label = 'Weed Grow' },
        },
        process = {
            { coords = vector3(2001.0, 4980.0, 41.5), radius = 6.1, label = 'Weed Process' },
        },
    },
    meth = {
        grow = {
            { coords = vector3(1692.4, 3590.3, 35.6), radius = 3.0, label = 'Meth Cook Spot' },
        },
        process = {
            { coords = vector3(1700.0, 3597.0, 35.7), radius = 3.0, label = 'Finish Cook' },
        },
    },
    cocaine = {
        grow = {
            { coords = vector3(-444.2, 6016.1, 30.7), radius = 3.0, label = 'Coca Harvest Spot' },
        },
        process = {
            { coords = vector3(-451.0, 6021.0, 31.0), radius = 3.0, label = 'Process Cocaine' },
        },
    },
    heroin = {
        grow = {
            { coords = vector3(2965.1, 4820.5, 50.1), radius = 3.0, label = 'Opium Harvest Spot' },
        },
        process = {
            { coords = vector3(2972.0, 4827.0, 50.5), radius = 3.0, label = 'Process Heroin' },
        },
    },
}

-- Cooldown in seconds between uses of the same zone per player (0 = disabled)
Config.ZoneCooldown = 0

-- ============================================================
-- HEAT SYSTEM
-- Every sale increments the player's heat.
-- Heat decays passively over time.
-- At alertThreshold → narcotics alert fires for on-duty officers.
-- Heat resets to 0 after bust threshold is passed (officer discretion).
-- ============================================================
Config.Heat = {
    perSale        = 20,    -- heat added per successful sale
    decayPerMinute = 5,     -- heat removed per real-world minute
    alertThreshold = 60,    -- heat level that triggers an area narcotics alert
    bustedThreshold = 100,  -- heat level considered "hot"; extra alert detail
}

-- ============================================================
-- DIRTY MONEY
-- Drug sales pay dirty_money items instead of clean cash.
-- Players must visit the Launderer to convert to spendable cash.
-- ============================================================
Config.DirtyMoney = {
    enabled      = true,
    launderRate  = 0.65,  -- 65 cents on the dollar
    minAmount    = 100,   -- minimum dirty_money to launder at once
}

-- ============================================================
-- SUPPLY DEALER NPC
-- Sells seeds, precursors, and supply items for clean cash.
-- Adjust coords/heading to move them in-world.
-- ============================================================
Config.SupplyDealer = {
    coords  = vector3(-1171.52, -1570.86, 4.66),  -- Smoke on the Water
    heading = 124.58,
    ped     = 'a_m_y_beach_01',
    label   = 'Smoke on the Water Dealer',
    items   = {
        -- Weed seeds (quality tiers)
        { item = 'weed_seed1', label = 'Schwag Seeds (x5)',     count = 5,  price = 50   },
        { item = 'weed_seed',  label = 'Mid Seeds (x5)',         count = 5,  price = 150  },
        { item = 'weed_seed3', label = 'Loud Seeds (x5)',        count = 5,  price = 400  },
    },
}

-- ============================================================
-- LAUNDERER NPC
-- Exchanges dirty_money for clean cash at launderRate.
-- Adjust coords/heading to match your desired location.
-- ============================================================
Config.LaunderDealer = {
    coords  = vector3(-1039.8, -1436.5, 5.19),  -- El Burro Heights area — adjust as needed
    heading = 90.0,
    ped     = 'a_m_m_business_01',
    label   = 'Money Guy',
}

-- ============================================================
-- WEED SMOKEABLE CRAFTING
-- Keeps the item pool clean while still using multiple icon variants.
-- ============================================================
Config.WeedSmokeables = {
    -- Any of these papers can be used for joints
    paperItems = {
        'rolling_paper',
        'rolling_paper2',
        'paperroll',
    },

    -- ground_weed + paper => random visual joint variant
    joint = {
        inputItem  = 'ground_weed',
        inputCount = 1,
        outputPool = {
            'joint',
            'joint1',
            'joint2',
            'joint3',
            'joint4',
            'joint6',
            'joint7',
        },
        craftTime = 12,
    },

    -- ground_weed + bluntwrap => blunt
    blunt = {
        inputItem  = 'ground_weed',
        inputCount = 2,
        wrapItem   = 'bluntwrap',
        wrapCount  = 1,
        outputItem = 'blunt',
        craftTime  = 16,
    },

    -- strain_weed + paper => matching strain joint
    strainJoints = {
        { inputWeed = 'banana_kush_weed', outputJoint = 'banana_kush_joint', label = 'Banana Kush' },
        { inputWeed = 'blue_dream_weed',  outputJoint = 'blue_dream_joint',  label = 'Blue Dream'  },
        { inputWeed = 'og_kush_weed',     outputJoint = 'og_kush_joint',     label = 'OG Kush'     },
        { inputWeed = 'purple_haze_weed', outputJoint = 'purple_haze_joint', label = 'Purple Haze' },
    },
}

-- ============================================================
-- DRUG EFFECTS
-- Applied client-side when a player uses a drug product item.
-- duration = seconds the effect lasts
-- ============================================================
Config.DrugEffects = {
    weed    = { duration = 60,  speedMult = 0.85,  shake = false, shakeAmt = 0.0  },
    meth    = { duration = 90,  speedMult = 1.30,  shake = true,  shakeAmt = 0.04 },
    cocaine = { duration = 45,  speedMult = 1.40,  shake = true,  shakeAmt = 0.02 },
    heroin  = { duration = 120, speedMult = 0.60,  shake = false, shakeAmt = 0.0  },
}

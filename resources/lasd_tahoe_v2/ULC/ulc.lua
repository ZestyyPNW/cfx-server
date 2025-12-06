
--[[ 
  Ultimate Lighting Controller Config
  the ULC resource is required to use this configuration
  get the resource here: https://github.com/Flohhhhh/ultimate-lighting-controller/releases/latest
  To learn how to setup and use ULC visit here: https://docs.dwnstr.com/ulc/overview
]]
                
return {names = {"lasd15tahoe","lasd15tahoeb","lasd15k9","lasd15k9b","lasd20tahoe","lasd20tfs","lasd20k9"},
  steadyBurnConfig = {
    forceOn = false, useTime = false,
    disableWithLights = false,
    sbExtras = {}
  },
  parkConfig = {
    usePark = false,
    useSync = false,
    syncWith = {},
    pExtras = {},
    dExtras = {}
  },
  hornConfig = {
    useHorn = false,
    hornExtras = {},
    disableExtras = {}
  },
  brakeConfig = {
    useBrakes = false,
    speedThreshold = 3,
    brakeExtras = {},
    disableExtras = {}
  },
  reverseConfig = {
    useReverse = false,
    reverseExtras = {},
    disableExtras = {}
  },
  doorConfig = {
    useDoors = false,
    driverSide = {enable = {}, disable = {}},
    passSide = {enable = {}, disable = {}},
    trunk = {enable ={}, disable = {}}
  }, 
  buttons = {
    {label = "Stage 1", key = 1, color = "green", extra = 1, linkedExtras = {3}, oppositeExtras = {}, offExtras = {4,5,6,2}, repair = false},
		{label = "Stage 2", key = 2, color = "green", extra = 7, linkedExtras = {3,4,6,2}, oppositeExtras = {}, offExtras = {1,5}, repair = false},
		{label = "Stage 3", key = 3, color = "green", extra = 8, linkedExtras = {5,6,4}, oppositeExtras = {}, offExtras = {1,2,3}, repair = false}
  },
  stages = {
    useStages = false,
    stageKeys = {},
  },
  defaultStages = {
    useDefaults = false,
    enableKeys = {},
    disableKeys = {}
  }
},

{names = {"lasd20lp"},
  steadyBurnConfig = {
    forceOn = false, useTime = false,
    disableWithLights = false,
    sbExtras = {}
  },
  parkConfig = {
    usePark = false,
    useSync = false,
    syncWith = {},
    pExtras = {},
    dExtras = {}
  },
  hornConfig = {
    useHorn = false,
    hornExtras = {},
    disableExtras = {}
  },
  brakeConfig = {
    useBrakes = false,
    speedThreshold = 3,
    brakeExtras = {},
    disableExtras = {}
  },
  reverseConfig = {
    useReverse = false,
    reverseExtras = {},
    disableExtras = {}
  },
  doorConfig = {
    useDoors = false,
    driverSide = {enable = {}, disable = {}},
    passSide = {enable = {}, disable = {}},
    trunk = {enable ={}, disable = {}}
  }, 
  buttons = {
    {label = "Stage 1", key = 1, color = "green", extra = 1, linkedExtras = {3}, oppositeExtras = {}, offExtras = {2,4,5}, repair = false},
		{label = "Stage 2", key = 2, color = "green", extra = 6, linkedExtras = {2,3,5}, oppositeExtras = {}, offExtras = {4,1}, repair = false},
		{label = "Stage 3", key = 3, color = "green", extra = 7, linkedExtras = {4,5}, oppositeExtras = {}, offExtras = {1,3,2}, repair = false}
  },
  stages = {
    useStages = false,
    stageKeys = {},
  },
  defaultStages = {
    useDefaults = false,
    enableKeys = {},
    disableKeys = {}
  }
}
-- Emotes you add in the file will automatically be added to AnimationList.lua
-- If you have multiple custom list files they MUST be added between AnimationList.lua and Emote.lua in fxmanifest.lua!
-- Don't change 'CustomDP' it is local to this file!

-- Remove the } from the = {} then enter your own animation code ---
-- Don't forget to close the tables.

local CustomDP = {}

CustomDP.Expressions = {}
CustomDP.Walks = {}
CustomDP.Shared = {}
CustomDP.Dances = {}
CustomDP.AnimalEmotes = {}
CustomDP.Exits = {}
CustomDP.Emotes = {
    ["pavehcar1l"] = {
        "pavehcar1l@animations",
        "pavehcar1lclip",
        "Veh Sit-Up Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar1r"] = {
        "pavehcar1r@animations",
        "pavehcar1rclip",
        "Veh Sit-Up Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar2r"] = {
        "pavehcar2r@animations",
        "pavehcar2rclip",
        "Veh Hold On Tight Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar2l"] = {
        "pavehcar2l@animations",
        "pavehcar2lclip",
        "Veh Hold On Tight Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar3r"] = {
        "pavehcar3r@animations",
        "pavehcar3rclip",
        "Veh Sit Relaxs Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar3l"] = {
        "pavehcar3l@animations",
        "pavehcar3lclip",
        "Veh Sit Relaxs Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar4r"] = {
        "pavehcar4r@animations",
        "pavehcar4rclip",
        "Veh Sit and Wave Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar4l"] = {
        "pavehcar4l@animations",
        "pavehcar4lclip",
        "Veh Sit Cool Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar5r"] = {
        "pavehcar5r@animations",
        "pavehcar5rclip",
        "Veh Rock And Roll Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar5l"] = {
        "pavehcar5l@animations",
        "pavehcar5lclip",
        "Veh Rock And Roll Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["standpose"] = {
        "chxnchxo@stand_anim",
        "chxnchxostand_clip",
        "Stand Pose 0",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose1"] = {
        "chxnchxo@stand1_anim",
        "chxnchxostand1_clip",
        "Stand Pose 1",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose2"] = {
        "chxnchxo@stand2_anim",
        "chxnchxostand2_clip",
        "Stand Pose 2",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose3"] = {
        "chxnchxo@stand3_anim",
        "chxnchxostand3_clip",
        "Stand Pose 3",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose4"] = {
        "chxnchxo@stand4_anim",
        "chxnchxostand4_clip",
        "Stand Pose 4",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose5"] = {
        "chxnchxo@stand5_anim",
        "chxnchxostand5_clip",
        "Stand Pose 5",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose6"] = {
        "chxnchxo@stand6_anim",
        "chxnchxostand6_clip",
        "Stand Pose 6",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose7"] = {
        "chxnchxo@stand7_anim",
        "chxnchxostand7_clip",
        "Stand Pose 7",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose8"] = {
        "chxnchxo@stand8_anim",
        "chxnchxostand8_clip",
        "Stand Pose 8",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["standpose9"] = {
        "chxnchxo@stand9_anim",
        "chxnchxostand9_clip",
        "Stand Pose 9",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
            FullBody = true
        }
    },
    ["pavehcar6r"] = {
        "pavehcar6r@animations",
        "pavehcar6rclip",
        "Veh Sit Relaxs Roof Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar6l"] = {
        "pavehcar6l@animations",
        "pavehcar6lclip",
        "Veh Sit Relaxs Roof Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
	["pavehcar7r"] = {
        "pavehcar7r@animations",
        "pavehcar7rclip",
        "Veh Sit Happy Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar7l"] = {
        "pavehcar7l@animations",
        "pavehcar7lclip",
        "Veh Sit Happy Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar8r"] = {
        "pavehcar8r@animations",
        "pavehcar8rclip",
        "Veh Sleep Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar8l"] = {
        "pavehcar8l@animations",
        "pavehcar8lclip",
        "Veh Sleep Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar9r"] = {
        "pavehcar9r@animations",
        "pavehcar9rclip",
        "Veh Take Video Right",
        AnimationOptions = {
            Prop = "prop_phone_ing",
            PropBone = 28422,
            PropPlacement = {
                0.05,
                0.0100,
                0.060,
                -174.961,
                149.618,
                8.649,
            },
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar9l"] = {
        "pavehcar9l@animations",
        "pavehcar9lclip",
        "Veh Take Video Left",
        AnimationOptions = {
            Prop = "prop_phone_ing",
            PropBone = 58866,
            PropPlacement = {
                0.07,
                -0.0500,
                0.010,
                -105.33,
                -168.30,
                48.97,
            },
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pavehcar10"] = {
        "pavehcar10@animations",
        "pavehcar10clip",
        "Veh Sit Enjoy Lucia",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar1"] = {
        "pbvehcar1@animations",
        "pbvehcar1clip",
        "Veh Sit Here I Am",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar2"] = {
        "pbvehcar2@animations",
        "pbvehcar2clip",
        "Veh Sit Enjoy The Wind",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar3r"] = {
        "pbvehcar3r@animations",
        "pbvehcar3rclip",
        "Veh Sit Enjoy The Ride Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar3l"] = {
        "pbvehcar3l@animations",
        "pbvehcar3lclip",
        "Veh Sit Enjoy The Ride Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar4r"] = {
        "pbvehcar4r@animations",
        "pbvehcar4rclip",
        "Veh Sit Enjoy The Ride 2 Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar4l"] = {
        "pbvehcar4l@animations",
        "pbvehcar4lclip",
        "Veh Sit Enjoy The Ride 2 Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar5r"] = {
        "pbvehcar5r@animations",
        "pbvehcar5rclip",
        "Veh Sit Looking The View Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar5l"] = {
        "pbvehcar5l@animations",
        "pbvehcar5lclip",
        "Veh Sit Looking The View Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar6r"] = {
        "pbvehcar6r@animations",
        "pbvehcar6rclip",
        "Veh Twerk Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar6l"] = {
        "pbvehcar6l@animations",
        "pbvehcar6lclip",
        "Veh Twerk Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
	["pbvehcar7l"] = {
        "pbvehcar7l@animations",
        "pbvehcar7lclip",
        "Veh Standing At The Driver Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar8"] = {
        "pbvehcar8@animations",
        "pbvehcar8clip",
        "Veh Sleep On The Roof",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar9"] = {
        "pbvehcar9@animations",
        "pbvehcar9clip",
        "Veh Sit Relaxs On The Roof",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pbvehcar10"] = {
        "pbvehcar10@animations",
        "pbvehcar10clip",
        "Veh Relaxs On The Roof",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar1"] = {
        "pcvehcar1@animations",
        "pcvehcar1clip",
        "Veh Sit Enjoy On The Roof",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar2r"] = {
        "pcvehcar2r@animations",
        "pcvehcar2rclip",
        "Veh Sit Trunk Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar2l"] = {
        "pcvehcar2l@animations",
        "pcvehcar2lclip",
        "Veh Sit Trunk Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar3r"] = {
        "pcvehcar3r@animations",
        "pcvehcar3rclip",
        "Veh Sit Trunk Lower Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar3l"] = {
        "pcvehcar3l@animations",
        "pcvehcar3lclip",
        "Veh Sit Trunk Lower Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar4r"] = {
        "pcvehcar4r@animations",
        "pcvehcar4rclip",
        "Veh Fly Right",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar4l"] = {
        "pcvehcar4l@animations",
        "pcvehcar4lclip",
        "Veh Fly Left",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar5"] = {
        "pcvehcar5@animations",
        "pcvehcar5clip",
        "Veh Fly Random",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar6"] = {
        "pcvehcar6@animations",
        "pcvehcar6clip",
        "Veh Fly Higher",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar7"] = {
        "pcvehcar7@animations",
        "pcvehcar7clip",
        "Veh Motorcycle Hold On Tight",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar8"] = {
        "pcvehcar8@animations",
        "pcvehcar8clip",
        "Veh Motorcycle Two Gun",
        AnimationOptions = {
            Prop = 'w_pi_pistol',
            PropBone = 26611,
            PropPlacement = {
                0.07,
                -.01,
                0.01,
                -29.999,
                0.0,
                10.000
            },
            SecondProp = 'w_pi_pistol',
            SecondPropBone = 58867,
            SecondPropPlacement = {
                0.07,
                0.01,
                0.01,
                29.999,
                0.0,
                -10.000
            },
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["pcvehcar9"] = {
        "pcvehcar9@animations",
        "pcvehcar9clip",
        "Veh Motorcycle Sit Facing Back",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false,
			FullBody = true
        }
    },
    ["piru"] = {
        "piru@sharror",
        "piru_clip_ierrorr",
        "Piru Bloods Gangsign",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
			FullBody = true
        }
    },
    ["ccrip"] = {
        "compton_crip@sharror",
        "compton_crip_clip_ierrorr",
        "Compton Crips Gangsign",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
			FullBody = true
        }
    },
    ["crip"] = {
        "crip@sharror",
        "crip_clip_ierrorr",
        "Crips Gangsign",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
			FullBody = true
        }
    },
    ["hoovercrip"] = {
        "hoover_crip_gun@sharror",
        "hoover_crip_gun_clip_ierrorr",
        "Hoover Crips Gangsign",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
			FullBody = true
        }
    },
    ["latinkings"] = {
        "latin_kings@sharror",
        "latin_kings_clip_ierrorr",
        "Latin Kings Gangsign",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
			FullBody = true
        }
    },
    ["blood"] = {
        "blood@sharror",
        "blood_clip_ierrorr",
        "Bloods Gangsign",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
			FullBody = true
        }
    },
    ["mcrip"] = {
        "mafia_crips@sharror",
        "mafia_crips_clip_ierrorr",
        "Mafia Crips Gangsign",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
			FullBody = true
        }
    },

    ["shouldermica"] = {
        "shouldermica@cartoon",
        "shouldermica_clip",
        "Shoulder Mic A",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["chestmica"] = {
        "chestmica@cartoon",
        "chestmica_clip",
        "Chest Mic A",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["chestmicb"] = {
        "chestmicb@cartoon",
        "chestmicb_clip",
        "Chest Mic B",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["chestmicc"] = {
        "chestmicc@cartoon",
        "chestmicc_clip",
        "Chest Mic C",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["chestmicd"] = {
        "chestmicd@cartoon",
        "chestmicd_clip",
        "Chest Mic D",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["handhelda"] = {
        "handhelda@cartoon",
        "handhelda_clip",
        "Handheld A",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 36029,
            PropPlacement = { 0.0550, 0.0296, 0.0254, 99.9885, 3.6960, 135.0761 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["handheldb"] = {
        "handheldb@cartoon",
        "handheldb_clip",
        "Handheld B",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 6286,
            PropPlacement = { 0.0550, 0.0044, -0.0259, 82.6160, -3.2822, 143.3880 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["handheldc"] = {
        "handheldc@cartoon",
        "handheldc_clip",
        "Handheld C",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 36029,
            PropPlacement = { 0.0514, 0.0038, 0.0336, -81.2807, 28.9113, -57.9985 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["radioposea"] = {
        "radioposea@cartoon",
        "radioposea_clip",
        "Radio Pose A",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 36029,
            PropPlacement = { 0.0736, 0.0378, 0.0139, -133.8561, -27.1715, -18.7217 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["radioposeb"] = {
        "radioposeb@cartoon",
        "radioposeb_clip",
        "Radio Pose B",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 28422,
            PropPlacement = { 0.0750, 0.0230, -0.0230, -90.0000, 0.0, -60.0000 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["radioposec"] = {
        "radioposec@cartoon",
        "radioposec_clip",
        "Radio Pose C",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 28422,
            PropPlacement = { 0.0750, 0.0230, -0.0230, -90.0000, 0.0, -60.0000 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["radioposed"] = {
        "radioposed@cartoon",
        "radioposed_clip",
        "Radio Pose D",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 28422,
            PropPlacement = { 0.0750, 0.0230, -0.0230, -90.0000, 0.0, -60.0000 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["radioposee"] = {
        "radioposee@cartoon",
        "radioposee_clip",
        "Radio Pose E",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 36029,
            PropPlacement = { 0.0485, 0.0, 0.0292, 92.9499, 8.3679, 126.9386 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },
    ["radioposerest"] = {
        "radioposerest@cartoon",
        "radioposerest_clip",
        "Radio Pose Rest",
        AnimationOptions = {
            Prop = "prop_cs_hand_radio",
            PropBone = 28422,
            PropPlacement = { 0.0750, 0.0230, -0.0230, -90.0000, 0.0, -60.0000 },
            EmoteLoop = true,
            EmoteMoving = true,
        }
    },

    -- LEO Pose Pack No 2
    ["shieldaim"] = {
        "shieldaim@cartoon",
        "shieldaim_clip",
        "77 Shield Aim",
        AnimationOptions = {
            Prop = "prop_ballistic_shield",
            PropBone = 36029,
            PropPlacement = {
                0.027805600627403,
                -0.03255339951872,
                -0.060990139100079,
                90.982160207201,
                -21.248165304219,
                156.23947846669
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["leobinocularsveh"] = {
        "binocularsvehicle@cartoon",
        "binocularsvehicle_clip",
        "77 Binoculars Vehicle",
        AnimationOptions = {
            Prop = "prop_binoc_01",
            PropBone = 6286,
            PropPlacement = {
                0.11880772274878,
                0.044755202937534,
                -0.030747995481285,
                10.712522278647,
                0.64370422614106,
                -0.65416974457932
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["carrybag"] = {
        "carrybag@cartoon",
        "carrybag_clip",
        "77 Carry Bag",
        AnimationOptions = {
            Prop = "prop_michael_backpack",
            PropBone = 6286,
            PropPlacement = {
                0.23478111022837,
                -0.062836073036813,
                0.05806906884708,
                0.0,
                -85.490671204531,
                -108.86722308239
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["leobinoculars"] = {
        "binoculars@cartoon",
        "binoculars_clip",
        "77 Binoculars",
        AnimationOptions = {
            Prop = "prop_binoc_01",
            PropBone = 6286,
            PropPlacement = {
                0.11880772274878,
                0.044755202937534,
                -0.030747995481285,
                10.712522278647,
                0.64370422614106,
                -0.65416974457932
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["cb"] = {
        "cb@cartoon",
        "cb_clip",
        "77 Clipboard A2",
        AnimationOptions = {
            Prop = 'prop_pencil_01',
            PropBone = 6286,
            PropPlacement = {
                0.082928788343793,
                0.050464208571481,
                0.0020748404558257,
                -141.74078727319,
                -53.322357680409,
                -32.311792760138
            },
            SecondProp = 'p_cs_clipboard',
            SecondPropBone = 36029,
            SecondPropPlacement = {
                0.13524608440798,
                0.0085414392542884,
                0.03848810645006,
                -102.9315136172,
                -9.6983151103175,
                -0.69277493769757
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["lidar"] = {
        "lidar@cartoon",
        "lidar_clip",
        "77 LIDAR",
        AnimationOptions = {
            Prop = "w_pi_prolaser4",
            PropBone = 36029,
            PropPlacement = {
                0.062651141213223,
                0.0021050199691081,
                -0.018159487266964,
                -74.522617160545,
                46.233061926035,
                -49.36915210942
            },
            EmoteLoop = true
        }
    },

    ["leocamera"] = {
        "leocamera@cartoon",
        "leocamera_clip",
        "77 LEO Camera",
        AnimationOptions = {
            Prop = "prop_pap_camera_01",
            PropBone = 36029,
            PropPlacement = {
                0.13285316052281,
                0.0,
                0.069871774864649,
                33.227620230838,
                -6.1944443550355,
                -175.88357401961
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["paperwr"] = {
        "paperwr@cartoon",
        "paperwr_clip",
        "77 paperwr",
        AnimationOptions = {
            Prop = "prop_pencil_01",
            PropBone = 6286,
            PropPlacement = {
                0.060599656206591,
                0.046732695888124,
                -0.0063937846508236,
                -26.607334872995,
                15.587682866106,
                -103.26106259071
            },
            SecondProp = "prop_amanda_note_01",
            SecondPropBone = 36029,
            SecondPropPlacement = {
                0.090581818952046,
                -0.021753491438448,
                0.024546692684615,
                -14.695840764735,
                -23.31810343791,
                -26.166845974374
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["coffeebelt"] = {
        "coffeebelt@cartoon",
        "coffeebelt_clip",
        "77 Belt Coffee",
        AnimationOptions = {
            Prop = "p_ing_coffeecup_01",
            PropBone = 6286,
            PropPlacement = {
                0.068731374555,
                0.03139214340836,
                -0.023351558352198,
                -75.318575192433,
                -44.33497282459,
                -12.336044694332
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["onehandshield"] = {
        "onehandshield@cartoon",
        "onehandshield_clip",
        "77 One Hand Shield",
        AnimationOptions = {
            Prop = "prop_ballistic_shield",
            PropBone = 36029,
            PropPlacement = {
                0.019623858871796,
                -0.025687859612967,
                -0.054956156874566,
                126.81588071928,
                -45.954690237389,
                95.11293093132
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["duinotepad"] = {
        "duinotepad@cartoon",
        "duinotepad_clip",
        "77 DUI Notepad",
        AnimationOptions = {
            Prop = "prop_notepad_02",
            PropBone = 36029,
            PropPlacement = {
                0.07304768553945,
                0.023114004912767,
                0.027331673261111,
                -14.658680041603,
                -20.876521690057,
                7.0228241658896
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["duiclipboard"] = {
        "duiclipboard@cartoon",
        "duiclipboard_clip",
        "77 DUI Clipboard",
        AnimationOptions = {
            Prop = "p_amb_clipboard_01",
            PropBone = 36029,
            PropPlacement = {
                0.13993051195837,
                0.0,
                0.04676158289303,
                -110.49532870263,
                -11.090240893683,
                4.0392707320484
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["notepadradio"] = {
        "notepadradio@cartoon",
        "notepadradio_clip",
        "77 Notepad Radio",
        AnimationOptions = {
            Prop = "prop_notepad_01",
            PropBone = 6286,
            PropPlacement = {
                0.098910831737612,
                0.033324336140049,
                -0.016786314964707,
                168.36498169008,
                2.9810680288095,
                -179.95204094406
            },
            SecondProp = "prop_cs_hand_radio",
            SecondPropBone = 36029,
            SecondPropPlacement = {
                0.094187177673234,
                0.043123484030153,
                0.015793690996083,
                -119.28410788475,
                -21.670778059502,
                -38.557657668088
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["holddocs"] = {
        "holddocs@cartoon",
        "holddocs_clip",
        "77 Hold Documents",
        AnimationOptions = {
            Prop = "prop_cs_documents_01",
            PropBone = 36029,
            PropPlacement = {
                0.005071469297377,
                0.072759381748999,
                0.015371456632382,
                -2.1161039832604,
                0.82599121143218,
                -25.02156640569
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["gundowntaser"] = {
        "gundowntaser@cartoon",
        "gundowntaser_clip",
        "77 Gun Down Taser",
        AnimationOptions = {
            Prop = "w_pi_taser7green",
            PropBone = 36029,
            PropPlacement = {
                0.067057589686442,
                0.038482745768633,
                0.018129898457137,
                -112.9863938932,
                -8.5258401847759,
                2.6502677532856
            },
            EmoteLoop = true,
            EmoteMoving = true
        }
    },

    ["beltcnb"] = { "beltcnb@cartoon", "beltcnb_clip", "77 Beltcnb", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["beltgncs"] = { "beltgncs@cartoon", "beltgncs_clip", "77 Beltgncs", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["belthnr"] = { "belthnr@cartoon", "belthnr_clip", "77 Belthnr", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["beltidle3"] = { "beltidle3@cartoon", "beltidle3_clip", "77 Belt Idle 3", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["beltjsm"] = { "beltjsm@cartoon", "beltjsm_clip", "77 Beltjsm", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["beltohb"] = { "beltohb@cartoon", "beltohb_clip", "77 beltohb", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["checkdoor"] = { "checkdoor@cartoon", "checkdoor_clip", "77 Check Door", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["fence"] = { "fence@cartoon", "fence_clip", "77 Fence", AnimationOptions = { EmoteLoop = true } },
    ["gundownpartner"] = { "gundownpartner@cartoon", "gundownpartner_clip", "77 Gun Down Partner", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["gunuppartner"] = { "gunuppartner@cartoon", "gunuppartner_clip", "77 Gun Up Partner", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["leanpoint"] = { "leanpoint@cartoon", "leanpoint_clip", "77 Lean Point", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["radioidle"] = { "radioidle@cartoon", "radioidle_clip", "77 Radio Idle", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["vehiclelow"] = { "vehiclelow@cartoon", "vehiclelow_clip", "77 Vehicle Low", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["vehiclemed"] = { "vehiclemed@cartoon", "vehiclemed_clip", "77 Vehicle Med", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["vehiclehigh"] = { "vehiclehigh@cartoon", "vehiclehigh_clip", "77 Vehicle High", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["holdgunmid"] = { "holdgunmid@cartoon", "holdgunmid_clip", "77 Hold Gun Mid", AnimationOptions = { EmoteLoop = true, EmoteMoving = true } },
    ["sitcuffed"] = {
        "sitcuffed@cartoon",
        "sitcuffed_clip",
        "sitcuffed",
        AnimationOptions = {
            EmoteLoop = true,
            EmoteMoving = false
        }
    },
}
CustomDP.PropEmotes = {}

-----------------------------------------------------------------------------------------
--| I don't think you should change the code below unless you know what you are doing |--
-----------------------------------------------------------------------------------------

function LoadAddonEmotes()
    for arrayName, array in pairs(CustomDP) do
        if RP[arrayName] then
            for emoteName, emoteData in pairs(array) do
                RP[arrayName][emoteName] = emoteData
            end
        end
    end
    -- Free memory
    CustomDP = nil
end

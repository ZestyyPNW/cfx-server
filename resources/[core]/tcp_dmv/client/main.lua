if not lib then return end

local testLocation = vec3(241.09, -1379.48, 32.74)
local testActive = false
local currentTest = nil
local testStartTime = 0

-- License class questions (lengthy test with multiple questions per class)
local licenseTests = {
    ['class_c'] = {
        name = 'Class C - Standard Driver\'s License',
        questions = {
            {
                question = 'What is the speed limit in a school zone when children are present?',
                options = { '15 mph', '20 mph', '25 mph', '30 mph' },
                correct = 1
            },
            {
                question = 'When should you use your turn signals?',
                options = { 'Only when changing lanes', 'At least 100 feet before turning or changing lanes', 'Only in heavy traffic', 'Never required' },
                correct = 2
            },
            {
                question = 'What should you do when approaching a yellow traffic light?',
                options = { 'Speed up to beat the red light', 'Stop if you can do so safely', 'Always continue through', 'Honk your horn' },
                correct = 2
            },
            {
                question = 'What is the legal blood alcohol content (BAC) limit for drivers 21 and over?',
                options = { '0.05%', '0.08%', '0.10%', '0.15%' },
                correct = 2
            },
            {
                question = 'When parking on a hill facing downhill, which way should you turn your wheels?',
                options = { 'Toward the curb', 'Away from the curb', 'Straight ahead', 'Doesn\'t matter' },
                correct = 1
            },
            {
                question = 'What does a solid yellow line on your side of the road mean?',
                options = { 'You may pass if safe', 'No passing allowed', 'Passing allowed only during daylight', 'Passing allowed only for emergency vehicles' },
                correct = 2
            },
            {
                question = 'How far should you stay behind the vehicle in front of you?',
                options = { '1 second', '2 seconds', '3 seconds', '5 seconds' },
                correct = 3
            },
            {
                question = 'What should you do if you miss your exit on a freeway?',
                options = { 'Back up on the shoulder', 'Continue to the next exit', 'Make a U-turn', 'Stop and reverse' },
                correct = 2
            },
            {
                question = 'When is it legal to make a U-turn?',
                options = { 'Anywhere there is no oncoming traffic', 'Only at intersections with traffic lights', 'Where posted signs allow it', 'Never on city streets' },
                correct = 3
            },
            {
                question = 'What should you do if your vehicle starts to hydroplane?',
                options = { 'Accelerate to gain control', 'Brake hard', 'Steer straight and ease off the accelerator', 'Turn the steering wheel sharply' },
                correct = 3
            },
            {
                question = 'What does a red octagonal sign mean?',
                options = { 'Yield', 'Stop', 'No entry', 'Slow down' },
                correct = 2
            },
            {
                question = 'When should you yield the right-of-way?',
                options = { 'Only at stop signs', 'To pedestrians in crosswalks and emergency vehicles', 'Never, you always have right-of-way', 'Only to larger vehicles' },
                correct = 2
            },
            {
                question = 'What is the minimum following distance in ideal conditions?',
                options = { '1 car length', '2 seconds', '3 seconds', '5 seconds' },
                correct = 3
            },
            {
                question = 'What should you do when you see a school bus with flashing red lights?',
                options = { 'Slow down and proceed with caution', 'Stop until the lights stop flashing', 'Speed up to pass quickly', 'Only stop if children are visible' },
                correct = 2
            },
            {
                question = 'When driving in fog, you should:',
                options = { 'Use high beam headlights', 'Use low beam headlights', 'Drive faster to get through quickly', 'Turn off all lights' },
                correct = 2
            }
        }
    },
    ['class_b'] = {
        name = 'Class B - Commercial Vehicle License',
        questions = {
            {
                question = 'What is the maximum weight a Class B vehicle can tow?',
                options = { '5,000 lbs', '10,000 lbs', '15,000 lbs', 'No limit' },
                correct = 2
            },
            {
                question = 'How often should you check your mirrors when driving a commercial vehicle?',
                options = { 'Every 5-8 seconds', 'Every 10-15 seconds', 'Only when changing lanes', 'Once per minute' },
                correct = 1
            },
            {
                question = 'What is the minimum following distance for commercial vehicles?',
                options = { '2 seconds', '4 seconds', '6 seconds', '8 seconds' },
                correct = 3
            },
            {
                question = 'When should you use your hazard lights?',
                options = { 'When driving slowly', 'When stopped on the side of the road', 'When making turns', 'Never' },
                correct = 2
            },
            {
                question = 'What is the maximum speed for commercial vehicles on most highways?',
                options = { '55 mph', '60 mph', '65 mph', '70 mph' },
                correct = 1
            },
            {
                question = 'How long can you drive before taking a mandatory break?',
                options = { '4 hours', '6 hours', '8 hours', '10 hours' },
                correct = 3
            },
            {
                question = 'What should you check before starting your commercial vehicle?',
                options = { 'Only the engine', 'Tires, brakes, lights, and fluid levels', 'Only the fuel gauge', 'Nothing, just start driving' },
                correct = 2
            },
            {
                question = 'When backing a commercial vehicle, you should:',
                options = { 'Use only mirrors', 'Get out and check, use a spotter if possible', 'Back up quickly', 'Never back up' },
                correct = 2
            },
            {
                question = 'What is the maximum width for a commercial vehicle?',
                options = { '8 feet', '8.5 feet', '10 feet', '12 feet' },
                correct = 2
            },
            {
                question = 'When loading cargo, weight should be distributed:',
                options = { 'All in the front', 'All in the back', 'Evenly and secured properly', 'Doesn\'t matter' },
                correct = 3
            },
            {
                question = 'What should you do if your brakes fail?',
                options = { 'Panic and jump out', 'Use the emergency brake and downshift', 'Speed up', 'Turn off the engine' },
                correct = 2
            },
            {
                question = 'How often should you inspect your commercial vehicle?',
                options = { 'Once a month', 'Before each trip', 'Once a week', 'Only when something breaks' },
                correct = 2
            },
            {
                question = 'What is the maximum height for a commercial vehicle?',
                options = { '12 feet', '13.5 feet', '14 feet', '15 feet' },
                correct = 3
            },
            {
                question = 'When should you use engine braking?',
                options = { 'Never', 'Only on steep hills', 'To slow down on long downgrades', 'Only in emergency situations' },
                correct = 3
            },
            {
                question = 'What is required when transporting hazardous materials?',
                options = { 'Special license endorsement', 'No special requirements', 'Only for large quantities', 'Only for certain materials' },
                correct = 1
            }
        }
    },
    ['class_a'] = {
        name = 'Class A - Commercial Combination Vehicle License',
        questions = {
            {
                question = 'What is the minimum age to obtain a Class A license?',
                options = { '18 years', '21 years', '25 years', 'No age requirement' },
                correct = 1
            },
            {
                question = 'How should you check your fifth wheel connection?',
                options = { 'Visual inspection only', 'Check that it\'s locked and secure', 'Only check when loading', 'Never needs checking' },
                correct = 2
            },
            {
                question = 'What is the proper way to couple a trailer?',
                options = { 'Back up quickly and connect', 'Back up slowly, connect, and verify', 'Have someone else do it', 'Use automatic coupling only' },
                correct = 2
            },
            {
                question = 'When should you use the trailer hand brake?',
                options = { 'Never', 'Only when parking', 'To help control the vehicle on downgrades', 'Only in emergency' },
                correct = 3
            },
            {
                question = 'What is the maximum length for a combination vehicle?',
                options = { '50 feet', '60 feet', '65 feet', '75 feet' },
                correct = 3
            },
            {
                question = 'How should cargo be loaded in a trailer?',
                options = { 'All weight in the front', 'All weight in the back', '60% in the front, 40% in the back', 'Evenly distributed' },
                correct = 3
            },
            {
                question = 'What should you do if your trailer starts to sway?',
                options = { 'Speed up', 'Brake hard', 'Steer into the sway and slow down gradually', 'Turn sharply' },
                correct = 3
            },
            {
                question = 'How often should you check your trailer connections?',
                options = { 'Once per trip', 'Before each trip and periodically while driving', 'Only when something feels wrong', 'Never' },
                correct = 2
            },
            {
                question = 'What is the proper way to uncouple a trailer?',
                options = { 'Just drive away', 'Park on level ground, set brakes, disconnect safely', 'Have someone else do it', 'Use automatic uncoupling' },
                correct = 2
            },
            {
                question = 'What should you check when inspecting air brakes?',
                options = { 'Only the pressure gauge', 'Air pressure, leaks, and brake function', 'Nothing, they work automatically', 'Only when brakes fail' },
                correct = 2
            },
            {
                question = 'How should you approach a curve with a combination vehicle?',
                options = { 'At the same speed as a car', 'Slower than a car, wider turns', 'Faster to maintain momentum', 'Same as any vehicle' },
                correct = 2
            },
            {
                question = 'What is the minimum following distance for combination vehicles?',
                options = { '3 seconds', '5 seconds', '7 seconds', '10 seconds' },
                correct = 3
            },
            {
                question = 'When backing a combination vehicle, you should:',
                options = { 'Use only mirrors', 'Turn the steering wheel opposite to the direction you want the trailer to go', 'Back up quickly', 'Never back up' },
                correct = 2
            },
            {
                question = 'What should you do if your air brake pressure drops below 60 PSI?',
                options = { 'Continue driving', 'Pull over immediately and fix the problem', 'Speed up', 'Ignore it' },
                correct = 2
            },
            {
                question = 'What is required for transporting passengers in a commercial vehicle?',
                options = { 'Class A license only', 'Passenger endorsement', 'No special requirements', 'Only for large buses' },
                correct = 2
            },
            {
                question = 'How should you handle a skid in a combination vehicle?',
                options = { 'Brake hard', 'Steer into the skid and ease off accelerator', 'Accelerate', 'Turn sharply' },
                correct = 2
            },
            {
                question = 'What is the proper way to check your kingpin connection?',
                options = { 'Visual check only', 'Check that it\'s locked and secure with proper clearance', 'Only check when loading', 'Never needs checking' },
                correct = 2
            },
            {
                question = 'When should you use your trailer brakes?',
                options = { 'Never', 'Only when parking', 'To help control speed on downgrades', 'Only in emergency' },
                correct = 3
            },
            {
                question = 'What is the maximum weight for a combination vehicle?',
                options = { '60,000 lbs', '70,000 lbs', '80,000 lbs', 'No limit' },
                correct = 3
            },
            {
                question = 'How should you position your vehicle when making a right turn?',
                options = { 'Stay in the left lane', 'Start wide, finish tight', 'Start tight, finish wide', 'Same as a car' },
                correct = 2
            }
        }
    },
    ['motorcycle'] = {
        name = 'Motorcycle License',
        questions = {
            {
                question = 'What is the most important safety equipment for motorcyclists?',
                options = { 'Gloves', 'Helmet', 'Boots', 'Jacket' },
                correct = 2
            },
            {
                question = 'How should you position yourself in a lane?',
                options = { 'Always in the center', 'Where you are most visible and can see ahead', 'Always on the right side', 'Doesn\'t matter' },
                correct = 2
            },
            {
                question = 'What should you do when approaching an intersection?',
                options = { 'Speed up', 'Slow down and be extra cautious', 'Continue at same speed', 'Weave between cars' },
                correct = 2
            },
            {
                question = 'How should you handle a turn on a motorcycle?',
                options = { 'Brake in the turn', 'Slow before the turn, accelerate through', 'Speed up in the turn', 'Coast through' },
                correct = 2
            },
            {
                question = 'What is the proper way to stop quickly on a motorcycle?',
                options = { 'Use only front brake', 'Use only rear brake', 'Use both brakes evenly', 'Use front brake primarily, rear brake for support' },
                correct = 4
            },
            {
                question = 'When should you wear protective gear?',
                options = { 'Only on long trips', 'Only in bad weather', 'Every time you ride', 'Only on highways' },
                correct = 3
            },
            {
                question = 'How should you handle wet road conditions?',
                options = { 'Ride faster to get through quickly', 'Slow down and increase following distance', 'Same as dry conditions', 'Avoid riding entirely' },
                correct = 2
            },
            {
                question = 'What should you check before every ride?',
                options = { 'Only the fuel', 'Tires, brakes, lights, and fluid levels', 'Only the engine', 'Nothing' },
                correct = 2
            },
            {
                question = 'How should you position yourself when being passed?',
                options = { 'Move to the center of the lane', 'Stay in your lane position', 'Move to the shoulder', 'Speed up' },
                correct = 2
            },
            {
                question = 'What is the minimum following distance for motorcycles?',
                options = { '1 second', '2 seconds', '3 seconds', '4 seconds' },
                correct = 3
            },
            {
                question = 'When should you use your high beam headlight?',
                options = { 'Always', 'Only at night', 'When you need extra visibility and no oncoming traffic', 'Never' },
                correct = 3
            },
            {
                question = 'How should you handle a skid?',
                options = { 'Brake hard', 'Steer into the skid and ease off brake', 'Accelerate', 'Jump off' },
                correct = 2
            },
            {
                question = 'What should you do if you are being tailgated?',
                options = { 'Speed up', 'Slow down and let them pass', 'Brake check them', 'Weave between lanes' },
                correct = 2
            },
            {
                question = 'When is lane splitting legal in California?',
                options = { 'Never', 'Only on highways', 'When done safely and not prohibited', 'Only for emergency vehicles' },
                correct = 3
            },
            {
                question = 'What is the proper way to carry a passenger?',
                options = { 'They can ride anywhere', 'Only on designated passenger seat with footpegs', 'On the gas tank', 'Standing on the back' },
                correct = 2
            }
        }
    }
}

-- Create blip
local dmvBlip = AddBlipForCoord(testLocation.x, testLocation.y, testLocation.z)
SetBlipSprite(dmvBlip, 50) -- Changed from 225 to 50 (location marker) to avoid conflict with GST Mapper
SetBlipDisplay(dmvBlip, 4)
SetBlipScale(dmvBlip, 0.8)
SetBlipColour(dmvBlip, 3)
SetBlipAsShortRange(dmvBlip, true)
BeginTextCommandSetBlipName("STRING")
AddTextComponentString("DMV Testing Center")
EndTextCommandSetBlipName()

-- Create interaction point
local textUIShown = false
local dmvPoint = lib.points.new({
    coords = testLocation,
    distance = 50.0,
    nearby = function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = #(playerCoords - testLocation)
        
        -- Draw marker when nearby
        if distance < 50.0 then
            DrawMarker(2, testLocation.x, testLocation.y, testLocation.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 30, 150, 30, 200, false, false, 0, true, false, false, false)
        end
        
        -- Show text UI only when close enough (within 3.0 units)
        if distance < 3.0 then
            if not textUIShown then
                lib.showTextUI('[E] Take Driver\'s License Test', {
                    position = "top-center",
                    icon = 'fa-id-card',
                    style = {
                        borderRadius = 0,
                        backgroundColor = '#1f2937',
                        color = 'white'
                    }
                })
                textUIShown = true
            end
            
            -- Handle interaction
            if IsControlJustReleased(0, 38) then -- E key
                if testActive then
                    lib.notify({
                        type = 'error',
                        description = 'You are already taking a test!'
                    })
                    return
                end
                
                openLicenseMenu()
            end
        else
            -- Hide text UI when too far
            if textUIShown then
                lib.hideTextUI()
                textUIShown = false
            end
        end
    end
})

function openLicenseMenu()
    local options = {}
    
    for licenseType, testData in pairs(licenseTests) do
        table.insert(options, {
            title = testData.name,
            description = string.format('%d questions - Click to begin test', #testData.questions),
            icon = 'fa-id-card',
            onSelect = function()
                startTest(licenseType)
            end
        })
    end
    
    -- Add cancel option if test is active
    if testActive and currentTest then
        table.insert(options, {
            title = '---',
            disabled = true
        })
        table.insert(options, {
            title = 'Cancel Current Test',
            description = 'Abandon your current test',
            icon = 'fa-times',
            onSelect = function()
                currentTest = nil
                testActive = false
                lib.notify({
                    type = 'info',
                    description = 'Test cancelled'
                })
            end
        })
    end
    
    lib.registerContext({
        id = 'dmv_license_menu',
        title = 'DMV License Testing',
        options = options
    })
    
    lib.showContext('dmv_license_menu')
end

function startTest(licenseType)
    local test = licenseTests[licenseType]
    if not test then return end
    
    currentTest = {
        type = licenseType,
        name = test.name,
        questions = test.questions,
        currentQuestion = 1,
        answers = {},
        score = 0
    }
    
    testActive = true
    testStartTime = GetGameTimer()
    
    lib.notify({
        type = 'info',
        description = string.format('Starting %s test. Good luck!', test.name)
    })
    
    showQuestion()
end

function showQuestion()
    if not currentTest then return end
    
    local question = currentTest.questions[currentTest.currentQuestion]
    if not question then
        finishTest()
        return
    end
    
    local options = {}
    for i, option in ipairs(question.options) do
        table.insert(options, {
            title = option,
            description = 'Select this answer',
            icon = 'fa-circle',
            onSelect = function()
                selectAnswer(i)
            end
        })
    end
    
    local menuOptions = {
        {
            title = question.question,
            description = 'Read carefully and select your answer',
            icon = 'fa-question-circle',
            disabled = true
        },
        {
            title = '---',
            disabled = true
        }
    }
    
    for _, option in ipairs(options) do
        table.insert(menuOptions, option)
    end
    
    lib.registerContext({
        id = 'dmv_test_question',
        title = string.format('Question %d of %d', currentTest.currentQuestion, #currentTest.questions),
        menu = 'dmv_license_menu',
        options = menuOptions
    })
    
    lib.showContext('dmv_test_question')
end

function selectAnswer(answerIndex)
    if not currentTest then return end
    
    local question = currentTest.questions[currentTest.currentQuestion]
    currentTest.answers[currentTest.currentQuestion] = answerIndex
    
    if answerIndex == question.correct then
        currentTest.score = currentTest.score + 1
    end
    
    currentTest.currentQuestion = currentTest.currentQuestion + 1
    
    if currentTest.currentQuestion > #currentTest.questions then
        finishTest()
    else
        Wait(500) -- Brief pause between questions
        showQuestion()
    end
end

function finishTest()
    if not currentTest then return end
    
    local totalQuestions = #currentTest.questions
    local score = currentTest.score
    local percentage = math.floor((score / totalQuestions) * 100)
    local passed = percentage >= 80 -- 80% to pass
    local testDuration = math.floor((GetGameTimer() - testStartTime) / 1000) -- seconds
    
    testActive = false
    
    lib.registerContext({
        id = 'dmv_test_results',
        title = 'Test Results',
        menu = 'dmv_license_menu',
        options = {
            {
                title = string.format('Score: %d/%d (%d%%)', score, totalQuestions, percentage),
                description = passed and 'You passed!' or 'You failed. Need 80% to pass.',
                icon = passed and 'fa-check-circle' or 'fa-times-circle',
                disabled = true
            },
            {
                title = string.format('Time: %d seconds', testDuration),
                disabled = true
            },
            {
                title = '---',
                disabled = true
            },
            {
                title = 'Close',
                icon = 'fa-times',
                onSelect = function()
                    currentTest = nil
                    testActive = false
                end
            }
        }
    })
    
    lib.showContext('dmv_test_results')
    
    if passed then
        lib.notify({
            type = 'success',
            description = string.format('Congratulations! You passed the %s test!', currentTest.name)
        })
        
        -- Grant license via server
        TriggerServerEvent('tcp_dmv:grantLicense', currentTest.type)
    else
        lib.notify({
            type = 'error',
            description = string.format('You failed the test. You scored %d%%. You need 80%% to pass.', percentage)
        })
    end
    
    currentTest = nil
end

RegisterNetEvent('tcp_dmv:licenseGranted', function(licenseType)
    local licenseName = licenseType
    if licenseTests[licenseType] and licenseTests[licenseType].name then
        licenseName = licenseTests[licenseType].name
    end
    
    lib.notify({
        type = 'success',
        description = string.format('You have been granted your %s license!', licenseName)
    })
end)

RegisterNetEvent('tcp_dmv:licenseError', function(message)
    lib.notify({
        type = 'error',
        description = message or 'An error occurred while processing your license.'
    })
end)

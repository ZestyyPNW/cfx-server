function loadAnimDict(dict)
	local timeout = 0
	while not (HasAnimDictLoaded(dict) or (timeout >= 20)) do
		RequestAnimDict(dict, true)
		timeout = timeout + 1
		Citizen.Wait(50)
	end
end

function ShowInfo(text)
	SetTextComponentFormat("STRING")
	AddTextComponentString(text)
	DisplayHelpTextFromStringLabel(0, 0, 0, -1)
end

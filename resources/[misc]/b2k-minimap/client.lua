CreateThread(function()
    while true do
        Wait(500)
        -- Keep the NUI frame rendering if needed, though usually automatic.
        -- This is just a placeholder in case we need logic later.
        SetNuiFocus(false, false)
    end
end)
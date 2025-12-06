
Permissions = {}

function Permissions.hasAce(src, ace)
    if not Config.Framework.UseAce then return true end
    local allowed = IsPlayerAceAllowed(src, ace)
    Utils.debug(('Ace check %s -> %s'):format(ace, tostring(allowed)))
    return allowed
end

function Permissions.requireAce(src, ace)
    if not Permissions.hasAce(src, ace) then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Permission', 'You do not have permission.' } })
        return false
    end
    return true
end



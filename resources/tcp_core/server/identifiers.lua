Identifier = {}

function Identifier.get(src)
    local first = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if not first then first = id end
        if id:find('license2:') or id:find('license:') then
            return id
        end
    end
    return first
end

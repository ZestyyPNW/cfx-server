Config = Config or {}
Config.Framework = Config.Framework or {
    ResourceName = 'tcp_core',
    Debug = false,
    UseAce = true
}

Utils = {}

function Utils.debug(msg)
    if Config.Framework.Debug then
        print(('[%s] [DEBUG] %s'):format(Config.Framework.ResourceName, msg))
    end
end

function Utils.info(msg)
    print(('[%s] %s'):format(Config.Framework.ResourceName, msg))
end

function Utils.error(msg)
    print(('[%s] [ERROR] %s'):format(Config.Framework.ResourceName, msg))
end

-- tokagod Environment
-- Обёртка над executor-функциями

local Environment = {}

Environment.cloneref = cloneref or clonereference or function(obj) return obj end
Environment.gethui = gethui or function() return game:GetService("CoreGui") end
Environment.protectgui = protectgui or (syn and syn.protect_gui) or function() end

Environment.writefile = writefile
Environment.readfile = readfile
Environment.isfile = isfile
Environment.isfolder = isfolder
Environment.makefolder = makefolder
Environment.listfiles = listfiles
Environment.delfile = delfile

Environment.hookmetamethod = hookmetamethod
Environment.newcclosure = newcclosure
Environment.getnamecallmethod = getnamecallmethod

Environment.fireproximityprompt = fireproximityprompt
Environment.firesignal = firesignal
Environment.firetouchinterest = firetouchinterest
Environment.replicatesignal = replicatesignal

Environment.getconnections = getconnections
Environment.getcustomasset = getcustomasset
Environment.setclipboard = setclipboard

Environment.request = request or http_request or (syn and syn.request)

Environment.identifyexecutor = identifyexecutor

function Environment.Check(Array)
    for _, name in ipairs(Array) do
        if not Environment[name] then
            return false
        end
    end
    return true
end

return Environment

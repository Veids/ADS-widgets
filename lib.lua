local lib = {}

-- Create tracking table
function lib.trackingTable(callback)
    local metaTable

    do
      local protectedTable = {}
      metaTable = {
        __index = function (_,k)
          return protectedTable[k]
        end,
        __newindex = function (t,k,v)
          protectedTable[k] = v   -- update original table
          callback(t,k,v)
        end
      }
    end

    local t = setmetatable({}, metaTable)
    return t
end

function lib.secondsToClock(seconds, strip)
    local hours = string.format("%02.f", math.floor(seconds/3600))
    local mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)))
    local secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60))

    if strip and not hours then
        return mins .. ":" .. secs
    else
        return hours .. ":" .. mins .. ":" .. secs
    end
end

return lib

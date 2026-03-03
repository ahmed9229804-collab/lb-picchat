



if not Config.LiveLocation.Enabled then
    return
end
local interval = math.floor(math.max(Config.LiveLocation.Interval or 30000, 1000))
local tracking = {}
function StartTrackingLocation(username, source, phoneNumber)
    debugprint("StartTrackingLocation", username)
    for i = 1, #tracking do
        if tracking[i].username == username then
            return
        end
    end
    tracking[#tracking + 1] = {
        username = username,
        phoneNumber = phoneNumber,
        source = source,
    }
end
function StopTrackingLocation(username)
    debugprint("StopTrackingLocation", username)
    for i = 1, #tracking do
        if tracking[i].username == username then
            table.remove(tracking, i)
            return
        end
    end
end
local warnedOldVersion = false
local function HasPhoneItem(source, phoneNumber)
    if not Config.LiveLocation.RequireItem then
        return true
    end
    local success, hasItem = pcall(function()
        return exports["lb-phone"]:HasPhoneItem(source, phoneNumber)
    end)
    if not success then
        if not warnedOldVersion then
            warnedOldVersion = true
            infoprint("error", "You are using an old version of LB Phone. Please update to the latest version.")
        end
        return true
    end
    return hasItem
end
while true do
    Wait(interval)
    local locations = {}
    for i = 1, #tracking do
        local data = tracking[i]
        local source = data.source
        local phoneNumber = data.phoneNumber
        if not HasPhoneItem(source, phoneNumber) or exports["lb-phone"]:IsPhoneDead(phoneNumber) then
            goto continue
        end
        local location = UpdateLocation(data.username, true)
        if location then
            locations[#locations + 1] = {
                username = data.username,
                location = location,
            }
        end
        ::continue::
    end
    if #locations > 0 then
        TriggerClientEvent("lb-picchat:updateLocations", -1, locations)
    end
end

         


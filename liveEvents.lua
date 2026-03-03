local APP_IDENTIFIER = "lb-picchat"

local isPhoneVisible = false
local isPicchatAppOpen = false
local isCameraModeActive = false
local isUpdatingCoords = false

local phoneExports
local uiPagePath
local currentResourceName = GetCurrentResourceName()

while true do
    local phoneResourceState = GetResourceState("lb-phone")
    if "started" == phoneResourceState then
        break
    end
    Wait(500)
end

Wait(1000)

phoneExports = exports["lb-phone"]
isPhoneVisible = phoneExports.IsOpen(phoneExports)

uiPagePath = GetResourceMetadata(currentResourceName, "ui_page", 0)

local function registerPicchatApp()
    local appDetails = {}
    appDetails.identifier = APP_IDENTIFIER

    local appConfig = Config.App
    appDetails.name = (appConfig and appConfig.Name) or "PicChat"

    appDetails.description = (appConfig and appConfig.Description) or "Social media platform for sharing photos and chatting with friends."
    
    appDetails.developer = "LB"
    appDetails.defaultApp = (appConfig and appConfig.Default)
    appDetails.size = 59812

    appDetails.images = {
        string.format("https://cfx-nui-%s/ui/dist/screenshot-light.png", currentResourceName),
        string.format("https://cfx-nui-%s/ui/dist/screenshot-dark.png", currentResourceName)
    }

    local uiUrl = uiPagePath
    if string.find(uiUrl, "http") then
        uiUrl = uiPagePath
    else
        uiUrl = string.format("%s/%s", currentResourceName, uiPagePath)
    end
    appDetails.ui = uiUrl

    local iconUrl = uiPagePath
    if string.find(iconUrl, "http") then
        iconUrl = uiPagePath .. "PicChat.png"
    else
        iconUrl = string.format("https://cfx-nui-%s/ui/dist/PicChat.png", currentResourceName)
    end
    appDetails.icon = iconUrl

    appDetails.fixBlur = true

    appDetails.onOpen = function()
        isPicchatAppOpen = true
        TriggerServerEvent("lb-picchat:openedApp")
    end

    appDetails.onClose = function()
        TriggerServerEvent("lb-picchat:closedApp")
        phoneExports.DisableWalkableCam(phoneExports)
        phoneExports.ToggleFlashlight(phoneExports, false)
        isPicchatAppOpen = false
        isCameraModeActive = false
    end

    local success, errorMessage = phoneExports.AddCustomApp(phoneExports, appDetails)
    if not success then
        print("Could not add app:", errorMessage)
    end
    debugprint("Added app", success, errorMessage)
end

registerPicchatApp()

AddEventHandler("onResourceStart", function(resourceName)
    if "lb-phone" == resourceName then
        registerPicchatApp()
    end
end)

local function getPostsForUser(username)
    local posts = AwaitCallback("getPosts", username)
    for i = 1, #posts do
        local post = posts[i]
        if post.metadata then
            post.metadata = json.decode(post.metadata)
        end
        post.timestamp = post.sent_at
        post.sent_at = nil
    end
    return posts
end

local function getMessagesForChat(username, lastMessageId)
    local messages = AwaitCallback("getMessages", username, lastMessageId)
    for i = 1, #messages do
        local message = messages[i]
        if "chat" == message.post_type and message.metadata then
            local attachmentPrefix = "<!ATTACHMENTS!>:"
            if string.sub(message.metadata, 1, #attachmentPrefix) == attachmentPrefix then
                message.metadata = string.gsub(message.metadata, attachmentPrefix, "")
                message.attachments = json.decode(message.metadata)
                message.metadata = nil
            end
        end

        local formattedMessage = {}
        formattedMessage.id = message.id
        formattedMessage.sender = message.sender
        formattedMessage.type = message.post_type

        local content
        if "chat" == formattedMessage.type then
            content = message.metadata or ""
        end
        formattedMessage.content = content

        formattedMessage.attachment = message.link
        formattedMessage.attachments = message.attachments

        local mediaMetadata
        if "media" == formattedMessage.type and message.metadata then
            mediaMetadata = json.decode(message.metadata)
        end
        formattedMessage.metadata = mediaMetadata

        formattedMessage.opened = message.opened
        formattedMessage.saved = message.saved
        formattedMessage.timestamp = message.sent_at

        messages[i] = formattedMessage
    end
    return messages
end

local function formatLocation(coords)
    local locationData = { x = coords.x, y = coords.y }

    local success, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, 1000.0, false)
    local zCoord = (success and groundZ) or 100.0

    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, zCoord)
    local streetName = streetHash and GetStreetNameFromHashKey(streetHash)

    local zoneHash = GetNameOfZone(coords.x, coords.y, zCoord)
    local zoneName = zoneHash and GetLabelText(zoneHash)

    if streetName then
        locationData.street = streetName
    end
    if zoneName then
        locationData.zone = zoneName
    end
    return locationData
end

local function getLoggedInUserData()
    local loggedInUser = AwaitCallback("getLoggedIn")
    if not loggedInUser then
        return false
    end

    if loggedInUser.friends then
        for i = 1, #loggedInUser.friends do
            local friend = loggedInUser.friends[i]
            if friend.location then
                friend.location = formatLocation(friend.location)
            end
        end
    end
    return loggedInUser
end

local function getSavedMedia(username, lastId)
    local resultImages = {}
    local savedPosts = AwaitCallback("getSavedPosts", username, lastId)

    for i = 1, #savedPosts do
        local post = savedPosts[i]
        if "chat" == post.post_type and post.metadata then
            local attachmentPrefix = "<!ATTACHMENTS!>:"
            if string.sub(post.metadata, 1, #attachmentPrefix) == attachmentPrefix then
                post.metadata = string.gsub(post.metadata, attachmentPrefix, "")
                local attachments = json.decode(post.metadata)
                for j = 1, #attachments do
                    local attachmentEntry = {
                        sender = post.sender,
                        link = attachments[j]
                    }
                    table.insert(resultImages, attachmentEntry)
                end
            end
        elseif "media" == post.post_type then
            local mediaEntry = {
                id = post.id,
                sender = post.sender,
                link = post.link,
                metadata = post.metadata and json.decode(post.metadata)
            }
            table.insert(resultImages, mediaEntry)
        end
    end
    return resultImages
end

local function uploadPlayerAvatar()
    for i = 1, 32 do
        if IsPedheadshotValid(i) then
            UnregisterPedheadshot(i)
        end
    end

    local playerPed = PlayerPedId()
    local headshotHandle = RegisterPedheadshot(playerPed)
    local timeoutTime = GetGameTimer() + 5000

    while true do
        if IsPedheadshotReady(headshotHandle) and IsPedheadshotValid(headshotHandle) then
            break
        end
        Wait(0)
        if timeoutTime <= GetGameTimer() then
            return
        end
    end

    local txdString = GetPedheadshotTxdString(headshotHandle)
    local avatarUrl = string.format("https://nui-img/%s/%s", txdString, txdString)
    SendReactMessage("uploadAvatar", avatarUrl)
end

local function getMediaMetadata()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    local altitudeMeters = math.floor(coords.z + 0.5)

    local success, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    local zCoord = (success and groundZ) or coords.z

    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, zCoord)
    local streetName = streetHash and GetStreetNameFromHashKey(streetHash)

    local zoneHash = GetNameOfZone(coords.x, coords.y, zCoord)
    local zoneName = zoneHash and GetLabelText(zoneHash)

    local metadata = {}

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local speedMPS = GetEntitySpeed(vehicle)
        if speedMPS and speedMPS > 1 then
            metadata.speed = {
                kph = math.floor(speedMPS * 3.6 + 0.5),
                mph = math.floor(speedMPS * 2.236936 + 0.5)
            }
        end
    end

    if streetName then
        metadata.street = streetName
    end
    if zoneName then
        metadata.zone = zoneName
    end

    metadata.altitude = {
        meters = altitudeMeters,
        feet = math.floor(altitudeMeters * 3.2808399 + 0.5)
    }

    return metadata
end

local function toggleSelfieCamera()
    if not isCameraModeActive then
        return
    end
    local isSelfieCam = phoneExports.IsSelfieCam(phoneExports)
    phoneExports.ToggleSelfieCam(phoneExports, not isSelfieCam)
end

local function startCoordUpdateLoop()
    local playerPed = PlayerPedId()
    while isUpdatingCoords do
        if isPicchatAppOpen and isPhoneVisible then
            local coords = GetEntityCoords(playerPed)
            SendReactMessage("updateCoords", { x = coords.x, y = coords.y })
        end
        Wait(100)
    end
end

local function handlePicchatNuiCallback(data, cb)
    local action = data.action

    if action == "getConfig" then
        return cb({
            deleteAccount = Config.DeleteAccount,
            changePassword = Config.ChangePassword,
            debug = Config.Debug,
            units = Config.Units
        })
    elseif action == "getLocales" then
        return cb(GetLocales())
    elseif action == "toggleUpdateCoords" then
        cb("ok")
        local newToggleState = (data.toggle == true)
        if isUpdatingCoords == newToggleState then
            return
        end
        isUpdatingCoords = newToggleState
        startCoordUpdateLoop()
    elseif action == "getLoggedIn" then
        return cb(getLoggedInUserData())
    elseif action == "createAccount" then
        return TriggerCallback("createAccount", cb, data.data)
    elseif action == "login" then
        return TriggerCallback("login", cb, data.data.username, data.data.password)
    elseif action == "logout" then
        return TriggerCallback("logout", cb)
    elseif action == "saveSettings" then
        return TriggerCallback("saveSettings", cb, data.settings)
    elseif action == "setName" then
        return TriggerCallback("setName", cb, data.name)
    elseif action == "updateAvatar" then
        uploadPlayerAvatar()
        return cb("ok")
    elseif action == "setAvatar" then
        return TriggerCallback("setAvatar", cb, data.url)
    elseif action == "changePassword" then
        return TriggerCallback("changePassword", cb, data.oldPassword, data.newPassword)
    elseif action == "deleteAccount" then
        return TriggerCallback("deleteAccount", cb, data.password)
    elseif action == "toggleCameraView" then
        local cameraModeEnabled = (data.toggle == true)
        isCameraModeActive = cameraModeEnabled
        if cameraModeEnabled then
            phoneExports.EnableWalkableCam(phoneExports)
        else
            phoneExports.DisableWalkableCam(phoneExports)
            phoneExports.ToggleFlashlight(phoneExports, false)
        end
        return cb("ok")
    elseif action == "flipCamera" then
        toggleSelfieCamera()
        return cb("ok")
    elseif action == "toggleFlash" then
        if not isCameraModeActive then
            debugprint("toggleFlash: not in camera")
            return cb(false)
        end
        local flashEnabled = (data.toggle == true)
        phoneExports.ToggleFlashlight(phoneExports, flashEnabled)
        return cb("ok")
    elseif action == "getMediaMetadata" then
        return cb(getMediaMetadata())
    elseif action == "searchUsers" then
        return TriggerCallback("searchUsers", cb, data.search, data.page)
    elseif action == "getContacts" then
        return TriggerCallback("getContacts", cb)
    elseif action == "addFriend" then
        return TriggerCallback("addFriend", cb, data.username)
    elseif action == "acceptFriend" then
        local friendData = AwaitCallback("acceptFriend", data.username)
        debugprint(friendData)
        if friendData and friendData.location then
            friendData.location = formatLocation(friendData.location)
        end
        return cb(friendData)
    elseif action == "removeFriend" then
        return TriggerCallback("removeFriend", cb, data.username)
    elseif action == "setFriendNickname" then
        return TriggerCallback("setFriendNickname", cb, data.username, data.name)
    elseif action == "toggleBestFriend" then
        return TriggerCallback("toggleBestFriend", cb, data.username, data.toggle)
    elseif action == "getPosts" then
        return cb(getPostsForUser(data.username))
    elseif action == "sendPost" then
        local metadataJson = data.data.metadata and json.encode(data.data.metadata)
        return TriggerCallback("sendPost", cb, data.data.usernames, data.data.link, (data.data.isVideo == true), metadataJson)
    elseif action == "viewedPosts" then
        return TriggerCallback("markPostsAsOpened", cb, data.posts, data.username)
    elseif action == "toggleSave" then
        return TriggerCallback("toggleSavePost", cb, data.state, data.id, data.username)
    elseif action == "toggleTyping" then
        return TriggerCallback("toggleTyping", cb, data.username, data.state)
    elseif action == "toggleInChat" then
        return TriggerCallback("toggleInChat", cb, data.username, data.state)
    elseif action == "getChatStatus" then
        return TriggerCallback("getChatStatus", cb, data.username)
    elseif action == "sendMessage" then
        local attachmentsJson = data.attachments and json.encode(data.attachments)
        return TriggerCallback("sendMessage", cb, data.username, data.content, attachmentsJson)
    elseif action == "getMessages" then
        return cb(getMessagesForChat(data.username, data.lastId))
    elseif action == "getSavedPosts" then
        return cb(getSavedMedia(data.username, data.lastId))
    elseif action == "getStories" then
        return TriggerCallback("getStories", cb, data.username)
    elseif action == "viewedStories" then
        return TriggerCallback("markStoriesAsViewed", cb, data.stories, data.username)
    elseif action == "removeStory" then
        return TriggerCallback("removeStory", cb, data.id)
    elseif action == "getStoryViewers" then
        return TriggerCallback("getStoryViewers", cb, data.id)
    end
    debugprint("Unknown action:", action)
end
RegisterNUICallback("PicChat", handlePicchatNuiCallback)

local function handlePhoneToggled(isVisible)
    isPhoneVisible = isVisible
    if not isPicchatAppOpen then
        return
    end

    if isVisible then
        if isCameraModeActive then
            phoneExports.EnableWalkableCam(phoneExports)
        end
    else
        phoneExports.DisableWalkableCam(phoneExports)
        phoneExports.ToggleFlashlight(phoneExports, false)
    end
end
RegisterNetEvent("lb-phone:phoneToggled", handlePhoneToggled)

local function handlePhoneKeyPressed(key)
    if not (isCameraModeActive and isPicchatAppOpen and isPhoneVisible) then
        return
    end

    if key == "FlipCamera" then
        toggleSelfieCamera()
    elseif key == "TakePhoto" then
        SendReactMessage("takePhoto")
    elseif key == "ToggleFlash" then
        SendReactMessage("toggleFlash")
    elseif key == "LeftMode" then
        SendReactMessage("changeMode", "left")
    elseif key == "RightMode" then
        SendReactMessage("changeMode", "right")
    end
end
AddEventHandler("lb-phone:keyPressed", handlePhoneKeyPressed)
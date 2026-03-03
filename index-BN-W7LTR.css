local accountsCache, phoneNumberToUsernameMap, inChatStatus
accountsCache = {}
phoneNumberToUsernameMap = {}
inChatStatus = {}

local function registerCallbackWithAccountCheck(eventName, callback, defaultReturnValue)
    local function wrappedCallback(source, phoneNumber, ...)
        local username = phoneNumberToUsernameMap[phoneNumber]
        if not username then
            debugprint("^1%s^7: no account found for %s | %s", eventName, GetPlayerName(source), phoneNumber)
            return defaultReturnValue
        end
        return callback(source, phoneNumber, username, ...)
    end
    BaseCallback(eventName, wrappedCallback, defaultReturnValue)
end

local function getPhoneNumbersByUsername(username)
    local phones = {}
    for phoneNum, cachedUsername in pairs(phoneNumberToUsernameMap) do
        if cachedUsername == username then
            local entry = {}
            entry.phoneNumber = phoneNum
            entry.source = exports["lb-phone"]:GetSourceFromNumber(phoneNum)
            table.insert(phones, entry)
        end
    end
    return phones
end

local function updateAccountLocation(username, dontTriggerClient)
    local account = accountsCache[username]
    local settings = account and account.settings
    local showLocation = settings and settings.showLocation

    if not showLocation then
        return
    end

    local coords = GetEntityCoords(GetPlayerPed(account.source))
    account.lastSeen = os.time() * 1000

    account.location = {
        x = coords.x,
        y = coords.y
    }

    if not dontTriggerClient then
        TriggerClientEvent("lb-picchat:updateLocation", -1, username, account.location)
    end
    return account.location
end
UpdateLocation = updateAccountLocation

local function sendNotificationToAccount(username, notificationData)
    local result = MySQL.query.await("SELECT phone_number FROM lbpicchat_logged_in WHERE username = ?", {username})
    notificationData.app = "lb-picchat"
    for i = 1, #result do
        local phoneNumber = result[i].phone_number
        exports["lb-phone"]:SendNotification(phoneNumber, notificationData)
    end
end

local function triggerClientEventOnUser(username, eventName, ...)
    local userPhones = getPhoneNumbersByUsername(username)
    if #userPhones == 0 then
        debugprint("TriggerClientEventOnUser: No users logged in for username: %s", username)
        return
    end

    local packedArgs = msgpack.pack_args(...)
    local packedArgsLength = #packedArgs

    for i = 1, #userPhones do
        local source = userPhones[i].source
        if source then
            local success, err = pcall(TriggerClientEventInternal, eventName, tostring(source), packedArgs, packedArgsLength)
            if not success then
                debugprint("TriggerClientEventOnUser failed, event: %s error: %s", eventName, err)
            end
        end
    end
end

local function getFriendsForAccount(username)
    local query = [[
        SELECT
            f.username,
            f.friend,
            a.display_name AS `name`,
            a.avatar,
            a.points,
            a.location_x,
            a.location_y,
            a.settings,
            a.last_seen,
            s.link AS story_preview,
            v.viewer AS story_viewed,
            f.status,
            f.last_interaction_type,
            f.last_interaction_sender,
            f.last_interaction_opened,
            f.last_interaction_time,
            f.interaction_streak AS streaks,
            f.last_streak_time,
            f.last_streak_sender,
            f.points AS friendPoints,
            f.best_friend_username,
            f.best_friend_friend,
            f.friend_nickname,
            f.username_nickname,
            f.created_at AS `timestamp`
        FROM
            lbpicchat_friends f
        LEFT JOIN
            lbpicchat_accounts a ON a.username = (
                CASE
                    WHEN f.username = ? THEN f.friend
                    ELSE f.username
                END
            )
        LEFT JOIN
            lbpicchat_stories s ON s.id = a.story_id
        LEFT JOIN
            lbpicchat_stories_views v ON v.story_id = s.id AND v.viewer = ?
        WHERE
            f.username = ? OR f.friend = ?
    ]]
    local params = {username, username, username, username}
    local friendsData = MySQL.query.await(query, params)

    for i = 1, #friendsData do
        local friend = friendsData[i]
        local friendUsername = (friend.username == username) and friend.friend or friend.username
        
        local cachedFriendAccount = accountsCache[friendUsername]
        local friendSettings = cachedFriendAccount and cachedFriendAccount.settings or (friend.settings and json.decode(friend.settings))

        if friend.last_interaction_type then
            friend.lastInteraction = {
                type = friend.last_interaction_type,
                sender = friend.last_interaction_sender,
                opened = friend.last_interaction_opened,
                timestamp = friend.last_interaction_time
            }
        end

        if friend.last_streak_time and friend.streaks > 0 then
            friend.lastStreak = {
                time = friend.last_streak_time,
                sender = friend.last_streak_sender
            }
        end

        if friend.story_preview then
            friend.story = friend.story_preview
            friend.story_preview = nil
        end
        
        if friend.story_viewed then
            friend.storyViewed = (friend.story_viewed ~= nil)
            friend.story_viewed = nil
        end

        if friend.username == username then
            friend.bestFriend = friend.best_friend_username
            friend.name = friend.friend_nickname or friend.name
        else
            friend.bestFriend = friend.best_friend_friend
            friend.name = friend.username_nickname or friend.name
        end

        local friendShowLocation = friendSettings and friendSettings.showLocation
        if friendShowLocation then
            if cachedFriendAccount then
                local liveUpdate = friendSettings.liveUpdateLocation
                if liveUpdate then
                    updateAccountLocation(friendUsername)
                end
                friend.location = cachedFriendAccount.location
            else
                if friend.location_x and friend.location_y then
                    friend.location = {
                        x = friend.location_x,
                        y = friend.location_y
                    }
                end
            end
        end

        friend.lastSeen = (cachedFriendAccount and cachedFriendAccount.lastSeen) or friend.last_seen

        friend.best_friend_username = nil
        friend.best_friend_friend = nil
        friend.last_seen = nil
        friend.settings = nil
        friend.location_x = nil
        friend.location_y = nil
        friend.last_interaction_type = nil
        friend.last_interaction_sender = nil
        friend.last_interaction_opened = nil
        friend.last_interaction_time = nil
    end
    return friendsData
end

local function saveAccountAndRemoveFromCache(username)
    for phoneNum, cachedUsername in pairs(phoneNumberToUsernameMap) do
        if cachedUsername == username then
            return
        end
    end

    local account = accountsCache[username]
    local settingsJson = account.settings and json.encode(account.settings) or nil

    local location = {}
    if account.location then
        location.x = math.floor(account.location.x + 0.5)
        location.y = math.floor(account.location.y + 0.5)
    end

    MySQL.update(
        "UPDATE lbpicchat_accounts SET display_name = ?, settings = ?, location_x = ?, location_y = ?, last_seen = CURRENT_TIMESTAMP WHERE username = ?",
        {account.name, settingsJson, location.x, location.y, username}
    )

    accountsCache[username] = nil
    debugprint("Removed account from cache %s", username)

    if StopTrackingLocation then
        StopTrackingLocation(username)
    end
end

local function loadAccountAndCache(source, username, phoneNumber)
    local accountData = MySQL.single.await([[
        SELECT
            a.username,
            a.phone_number,
            a.display_name,
            a.avatar,
            a.points,
            a.location,
            a.notifications,
            a.settings,
            a.last_seen,
            s.link AS story
        FROM
            lbpicchat_accounts a
        LEFT JOIN
            lbpicchat_stories s ON s.id = a.story_id
        WHERE
            a.username = ?
    ]], {username})

    if not accountData then
        return
    end

    local cachedAccount = {}
    cachedAccount.username = accountData.username
    cachedAccount.phoneNumber = accountData.phone_number
    cachedAccount.name = accountData.display_name
    cachedAccount.points = accountData.points
    cachedAccount.avatar = accountData.avatar
    cachedAccount.notifications = accountData.notifications
    cachedAccount.settings = accountData.settings and json.decode(accountData.settings)
    cachedAccount.source = source
    cachedAccount.lastSeen = accountData.last_seen
    cachedAccount.story = accountData.story

    phoneNumberToUsernameMap[phoneNumber] = accountData.username
    accountsCache[accountData.username] = cachedAccount

    if StartTrackingLocation then
        local settings = cachedAccount.settings
        if settings and settings.showLocation and settings.liveUpdateLocation then
            StartTrackingLocation(username, source, phoneNumber)
        end
    end

    updateAccountLocation(username)

    return accountData, cachedAccount
end

registerCallbackWithAccountCheck(
    "getLoggedIn",
    function(source, phoneNumber, username)
        local cachedAccount = accountsCache[username]
        if cachedAccount then
            updateAccountLocation(username)
            local response = {
                account = cachedAccount,
                notificationCount = cachedAccount.notifications,
                friends = getFriendsForAccount(username)
            }
            return response
        end

        local dbUsername = MySQL.scalar.await("SELECT username FROM lbpicchat_logged_in WHERE phone_number = ?", {phoneNumber})
        if not dbUsername then
            return false
        end

        local fullAccountData, newCachedAccount = loadAccountAndCache(source, dbUsername, phoneNumber)
        if not fullAccountData or not newCachedAccount then
            return false
        end

        local response = {
            account = newCachedAccount,
            notificationCount = fullAccountData.notifications,
            friends = getFriendsForAccount(fullAccountData.username)
        }
        return response
    end
)

registerCallbackWithAccountCheck(
    "createAccount",
    function(source, phoneNumber, usernameArg, accountDetails)
        local displayName = accountDetails.name
        local password = accountDetails.password
        local newUsername = usernameArg:lower()

        local oldUsernameForPhoneNumber = phoneNumberToUsernameMap[phoneNumber]
        if oldUsernameForPhoneNumber then
            phoneNumberToUsernameMap[phoneNumber] = nil
            saveAccountAndRemoveFromCache(oldUsernameForPhoneNumber)
        end

        if not (displayName and password and newUsername) then
            if password then
                password = string.rep("*", #password) or password
            else
                password = nil
            end
            debugprint("Invalid data for createAccount: %s", accountDetails)
            return {success = false, error = "invalid_data"}
        end

        if not CheckIfUsernameIsValid(newUsername) then
            debugprint("Invalid username for createAccount: %s", newUsername)
            return {success = false, error = "invalid_username"}
        end

        local usernameExists = MySQL.scalar.await("SELECT 1 FROM lbpicchat_accounts WHERE username = ?", {newUsername})
        if usernameExists then
            return {success = false, error = "username_taken"}
        end

        local affectedRows = MySQL.update.await(
            "INSERT INTO lbpicchat_accounts (username, password, phone_number, display_name) VALUES (?, ?, ?, ?)",
            {newUsername, GetPasswordHash(password), phoneNumber, displayName}
        )

        if not (affectedRows > 0) then
            return {success = false, error = "unknown"}
        end

        Log(source, "info", L("LOGS.CREATED_ACCOUNT"), {phoneNumber = phoneNumber, username = newUsername, name = displayName})

        loadAccountAndCache(source, newUsername, phoneNumber)

        MySQL.update.await(
            "INSERT INTO lbpicchat_logged_in (phone_number, username) VALUES (?, ?)",
            {phoneNumber, newUsername}
        )

        return {success = true}
    end
)

registerCallbackWithAccountCheck(
    "login",
    function(source, phoneNumber, username, password)
        local storedPasswordHash = MySQL.scalar.await("SELECT password FROM lbpicchat_accounts WHERE username = ?", {username})
        if not storedPasswordHash then
            debugprint("Account not found for login: %s", username)
            return {error = "invalid_username"}
        end

        if not VerifyPasswordHash(password, storedPasswordHash) then
            debugprint("Incorrect password for login: %s", username)
            return {error = "wrong_password"}
        end

        MySQL.update(
            "INSERT INTO lbpicchat_logged_in (phone_number, username) VALUES (?, ?) ON DUPLICATE KEY UPDATE username = VALUES(username)",
            {phoneNumber, username}
        )

        local oldUsernameForPhoneNumber = phoneNumberToUsernameMap[phoneNumber]
        if oldUsernameForPhoneNumber then
            phoneNumberToUsernameMap[phoneNumber] = nil
            saveAccountAndRemoveFromCache(oldUsernameForPhoneNumber)
        end
        
        local fullAccountData, newCachedAccount = loadAccountAndCache(source, username, phoneNumber)
        if not fullAccountData or not newCachedAccount then
            return false
        end

        local response = {
            account = newCachedAccount,
            notificationCount = fullAccountData.notifications,
            friends = getFriendsForAccount(fullAccountData.username)
        }
        return response
    end
)

registerCallbackWithAccountCheck(
    "logout",
    function(source, phoneNumber, username)
        MySQL.update.await("DELETE FROM lbpicchat_logged_in WHERE phone_number = ?", {phoneNumber})
        phoneNumberToUsernameMap[phoneNumber] = nil
        saveAccountAndRemoveFromCache(username)
        return true
    end,
    false
)

registerCallbackWithAccountCheck(
    "saveSettings",
    function(source, phoneNumber, username, newSettings)
        local account = accountsCache[username]
        account.settings = newSettings

        if newSettings then
            if newSettings.showLocation then
                updateAccountLocation(username)
            else
                account.location = nil
                TriggerClientEvent("lb-picchat:removeLocation", -1, username)
            end

            MySQL.update(
                "UPDATE lbpicchat_accounts SET settings = ? WHERE username = ?",
                {json.encode(newSettings), username}
            )

            if newSettings and newSettings.showLocation then
                if newSettings.liveUpdateLocation then
                    if StartTrackingLocation then
                        StartTrackingLocation(username, source, phoneNumber)
                    end
                else
                    if StopTrackingLocation then
                        StopTrackingLocation(username)
                    end
                end
            end
        else
            if StopTrackingLocation then
                StopTrackingLocation(username)
            end
        end
        return true
    end,
    false
)

registerCallbackWithAccountCheck(
    "setName",
    function(source, phoneNumber, username, newName)
        local account = accountsCache[username]
        account.name = newName
        return true
    end,
    false
)

registerCallbackWithAccountCheck(
    "setAvatar",
    function(source, phoneNumber, username, newAvatar)
        local account = accountsCache[username]
        account.avatar = newAvatar
        MySQL.update(
            "UPDATE lbpicchat_accounts SET avatar = ? WHERE username = ?",
            {newAvatar, username}
        )
        return true
    end,
    false
)

registerCallbackWithAccountCheck(
    "deleteAccount",
    function(source, phoneNumber, username, password)
        if not Config.DeleteAccount then
            debugprint("Delete account is disabled")
            return false
        end

        local storedPasswordHash = MySQL.scalar.await("SELECT password FROM lbpicchat_accounts WHERE username = ?", {username})
        if not storedPasswordHash then
            debugprint("Account not found for deletion: %s", username)
            return false
        end

        if not VerifyPasswordHash(password, storedPasswordHash) then
            debugprint("Incorrect password for deletion: %s", username)
            return false
        end

        local affectedRows = MySQL.update.await("DELETE FROM lbpicchat_accounts WHERE username = ?", {username})
        if affectedRows > 0 then
            TriggerClientEvent("lb-picchat:accountDeleted", -1, username)

            for phoneNum, cachedUsername in pairs(phoneNumberToUsernameMap) do
                if cachedUsername == username then
                    phoneNumberToUsernameMap[phoneNum] = nil
                    debugprint("Removed %s from logged in due to account deletion (%s)", phoneNum, cachedUsername)
                end
            end
            accountsCache[username] = nil

            Log(source, "info", L("LOGS.DELETED_ACCOUNT"), {phoneNumber = phoneNumber, username = username})

            MySQL.update.await("DELETE FROM lbpicchat_logged_in WHERE username = ? AND phone_number != ?", {username, phoneNumber})
        end
        return affectedRows > 0
    end,
    false
)

registerCallbackWithAccountCheck(
    "changePassword",
    function(source, phoneNumber, username, oldPassword, newPassword)
        if not Config.ChangePassword then
            debugprint("Change password is disabled")
            return false
        end

        if oldPassword == newPassword then
            debugprint("Old and new password are the same for user: %s", username)
            return false
        end

        local storedPasswordHash = MySQL.scalar.await("SELECT password FROM lbpicchat_accounts WHERE username = ?", {username})
        if not storedPasswordHash then
            debugprint("Account not found for password change: %s", username)
            return false
        end

        if not VerifyPasswordHash(oldPassword, storedPasswordHash) then
            debugprint("Incorrect password for password change: %s", username)
            return false
        end

        local affectedRows = MySQL.update.await(
            "UPDATE lbpicchat_accounts SET password = ? WHERE username = ?",
            {GetPasswordHash(newPassword), username}
        )

        if affectedRows > 0 then
            triggerClientEventOnUser(username, "lb-picchat:passwordChanged", phoneNumber)

            for phoneNum, cachedUsername in pairs(phoneNumberToUsernameMap) do
                if cachedUsername == username and phoneNum ~= phoneNumber then
                    phoneNumberToUsernameMap[phoneNum] = nil
                    debugprint("Removed %s from logged in due to password change (%s)", phoneNum, cachedUsername)
                end
            end

            MySQL.update.await("DELETE FROM lbpicchat_logged_in WHERE username = ? AND phone_number != ?", {username, phoneNumber})
            
            Log(source, "info", L("LOGS.CHANGED_PASSWORD"), {phoneNumber = phoneNumber, username = username})
        end
        return affectedRows > 0
    end,
    false
)

registerCallbackWithAccountCheck(
    "searchUsers",
    function(source, phoneNumber, loggedInUsername, searchTerm, page)
        page = page or 0
        if searchTerm and #searchTerm <= 2 then
            debugprint("Too short search term: %s", searchTerm)
            return {}
        end

        searchTerm = "%" .. searchTerm .. "%"
        
        return MySQL.query.await([[
            SELECT
                a.username,
                a.display_name AS `name`,
                a.avatar
            FROM
                lbpicchat_accounts a
            LEFT JOIN lbpicchat_friends f
                ON (f.username = a.username AND f.friend = ?)
                OR (f.username = ? AND f.friend = a.username)
            WHERE
                (a.display_name LIKE ? OR a.username LIKE ?)
                AND f.username IS NULL
                AND a.username != ?
            LIMIT ?, ?
        ]], {loggedInUsername, loggedInUsername, searchTerm, searchTerm, loggedInUsername, page * 50, 50})
    end,
    {}
)

registerCallbackWithAccountCheck(
    "getContacts",
    function(source, phoneNumber, loggedInUsername)
        return MySQL.query.await([[
            SELECT
                a.username,
                a.display_name AS `name`,
                a.avatar
            FROM phone_phone_contacts c
            JOIN lbpicchat_logged_in l
                ON l.phone_number = c.contact_phone_number
            JOIN lbpicchat_accounts a
                ON l.username = a.username
            LEFT JOIN lbpicchat_friends f
                ON (f.username = a.username AND f.friend = ?) OR (f.username = ? AND f.friend = a.username)
            WHERE
                c.phone_number = ? AND f.username IS NULL AND JSON_EXTRACT(a.settings, '$.showContact') != 'false'
        ]], {loggedInUsername, loggedInUsername, phoneNumber})
    end,
    {}
)

registerCallbackWithAccountCheck(
    "addFriend",
    function(source, phoneNumber, senderUsername, recipientUsername)
        if recipientUsername == senderUsername then
            debugprint("Can't add yourself as a friend: %s", senderUsername)
            return false
        end

        local alreadyFriends = MySQL.scalar.await("SELECT 1 FROM lbpicchat_friends WHERE (username = ? AND friend = ?) OR (username = ? AND friend = ?)",
            {senderUsername, recipientUsername, recipientUsername, senderUsername}
        )
        if alreadyFriends then
            debugprint("Already friends/requested: %s -> %s", senderUsername, recipientUsername)
            return false
        end

        local affectedRows = MySQL.update.await("INSERT IGNORE INTO lbpicchat_friends (username, friend) VALUES (?, ?)", {senderUsername, recipientUsername})
        if not (affectedRows > 0) then
            return false
        end

        local senderAccount = accountsCache[senderUsername]
        triggerClientEventOnUser(recipientUsername, "lb-picchat:newFriendRequest", {
            username = senderUsername,
            name = senderAccount.name,
            avatar = senderAccount.avatar
        })
        return true
    end,
    false
)

registerCallbackWithAccountCheck(
    "acceptFriend",
    function(source, phoneNumber, acceptorUsername, requesterUsername)
        local affectedRows = MySQL.update.await(
            "UPDATE lbpicchat_friends SET status = 'accepted' WHERE username = ? AND friend = ? AND status = 'pending'",
            {requesterUsername, acceptorUsername}
        )
        if not (affectedRows > 0) then
            return false
        end

        local acceptorAccount = accountsCache[acceptorUsername]
        local requesterAccount = accountsCache[requesterUsername]

        triggerClientEventOnUser(requesterUsername, "lb-picchat:acceptFriend", {
            username = acceptorUsername,
            location = acceptorAccount and acceptorAccount.location,
            story = acceptorAccount and acceptorAccount.story,
            lastSeen = (acceptorAccount and acceptorAccount.lastSeen) or (os.time() * 1000)
        })
        
        local acceptorFriendData = {}
        acceptorFriendData.story = requesterAccount and requesterAccount.story
        acceptorFriendData.location = requesterAccount and requesterAccount.location
        
        acceptorFriendData.lastSeen = (requesterAccount and requesterAccount.lastSeen) or MySQL.scalar.await("SELECT last_seen FROM lbpicchat_accounts WHERE username = ?", {requesterUsername})

        return acceptorFriendData
    end,
    false
)

registerCallbackWithAccountCheck(
    "removeFriend",
    function(source, phoneNumber, username1, username2)
        local affectedRows = MySQL.update.await(
            "DELETE FROM lbpicchat_friends WHERE ((username = ? AND friend = ?) OR (username = ? AND friend = ?)) AND status != 'blocked'",
            {username1, username2, username2, username1}
        )
        if not (affectedRows > 0) then
            return false
        end

        MySQL.update(
            "DELETE FROM lbpicchat_posts WHERE (sender = ? AND recipient = ?) OR (sender = ? AND recipient = ?)",
            {username1, username2, username2, username1}
        )

        triggerClientEventOnUser(username2, "lb-picchat:removeFriend", username1)
        return true
    end,
    false
)

registerCallbackWithAccountCheck(
    "setFriendNickname",
    function(source, phoneNumber, loggedInAs, friendUsername, nickname)
        local affectedRows = MySQL.update.await([[
            UPDATE
                lbpicchat_friends
            SET
                friend_nickname = CASE WHEN username = @loggedInAs THEN @nickname ELSE friend_nickname END,
                username_nickname = CASE WHEN friend = @loggedInAs THEN @nickname ELSE username_nickname END
            WHERE
                (username = @loggedInAs AND friend = @friend)
                OR (username = @friend AND friend = @loggedInAs)
        ]], {
            ["@loggedInAs"] = loggedInAs,
            ["@friend"] = friendUsername,
            ["@nickname"] = nickname
        })
        return affectedRows > 0
    end,
    false
)

registerCallbackWithAccountCheck(
    "toggleBestFriend",
    function(source, phoneNumber, loggedInAs, friendUsername, toggle)
        toggle = (true == toggle)
        local affectedRows = MySQL.update.await([[
            UPDATE
                lbpicchat_friends
            SET
                best_friend_username = CASE WHEN username = @loggedInAs THEN @toggle ELSE best_friend_username END,
                best_friend_friend = CASE WHEN friend = @loggedInAs THEN @toggle ELSE best_friend_friend END
            WHERE
                (username = @loggedInAs AND friend = @friend)
                OR (username = @friend AND friend = @loggedInAs)
        ]], {
            ["@loggedInAs"] = loggedInAs,
            ["@friend"] = friendUsername,
            ["@toggle"] = toggle
        })
        return affectedRows > 0
    end,
    false
)

registerCallbackWithAccountCheck(
    "getMessages",
    function(source, phoneNumber, username1, username2, beforeId)
        local params = {username1, username2, username2, username1}
        local idCondition = ""
        if beforeId then
            idCondition = "AND id < ?"
            table.insert(params, beforeId)
        end

        local query = string.format([[
            SELECT
                id,
                sender,
                post_type,
                link,
                metadata,
                opened,
                saved,
                sent_at
            FROM
                lbpicchat_posts
            WHERE
                (sender = ? AND recipient = ?) OR (sender = ? AND recipient = ?) %s
            ORDER BY
                id DESC
            LIMIT 50
        ]], idCondition)

        return MySQL.query.await(query, params)
    end,
    {}
)

registerCallbackWithAccountCheck(
    "getSavedPosts",
    function(source, phoneNumber, username1, username2, beforeId)
        local params = {username1, username2, username2, username1}
        local idCondition = ""
        if beforeId then
            idCondition = "AND id < ?"
            table.insert(params, beforeId)
        end
        table.insert(params, 50)

        local query = string.format([[
            SELECT
                id,
                post_type,
                sender,
                link,
                metadata,
                sent_at AS `timestamp`
            FROM
                lbpicchat_posts
            WHERE
                ((recipient = ? AND sender = ?) or (recipient = ? AND sender = ?)) AND saved = 1 %s
            ORDER BY
                id DESC
            LIMIT ?
        ]], idCondition)

        return MySQL.query.await(query, params)
    end,
    {}
)

registerCallbackWithAccountCheck(
    "getPosts",
    function(source, phoneNumber, recipientUsername, senderUsername)
        return MySQL.query.await([[
            SELECT
                id,
                link,
                metadata,
                sent_at
            FROM
                lbpicchat_posts
            WHERE
                sender = ? AND recipient = ? AND opened = 0 AND post_type = 'media'
            ORDER BY
                sent_at ASC
        ]], {senderUsername, recipientUsername})
    end,
    {}
)

registerCallbackWithAccountCheck(
    "toggleSavePost",
    function(source, phoneNumber, username, toggleSave, postId, targetUsername)
        toggleSave = (true == toggleSave)
        local affectedRows = MySQL.update.await(
            "UPDATE lbpicchat_posts SET saved = ? WHERE (recipient = ? OR sender = ?) AND id = ?",
            {toggleSave, username, username, postId}
        )
        if not (affectedRows > 0) then
            return false
        end

        triggerClientEventOnUser(targetUsername, "lb-picchat:toggleSavePost", postId, toggleSave)
        return true
    end,
    false
)

local function updateChatStatus(chatPartnerUsername, loggedInUsername, inChatStatusUpdate, isTypingUpdate)
    local inChatToggleBool = (true == inChatStatusUpdate)
    local isTypingToggleBool = (true == isTypingUpdate)

    local currentChatStatusEntry = inChatStatus[chatPartnerUsername]

    if inChatToggleBool then
        if not currentChatStatusEntry then
            inChatStatus[chatPartnerUsername] = {
                username = loggedInUsername,
                typing = isTypingToggleBool
            }
            currentChatStatusEntry = inChatStatus[chatPartnerUsername]
        end
    else
        inChatStatus[chatPartnerUsername] = nil
        currentChatStatusEntry = nil
    end

    currentChatStatusEntry = inChatStatus[chatPartnerUsername]

    if currentChatStatusEntry then
        if currentChatStatusEntry.username ~= loggedInUsername then
            triggerClientEventOnUser(currentChatStatusEntry.username, "lb-picchat:toggleInChat", chatPartnerUsername, false)
            if currentChatStatusEntry.typing then
                triggerClientEventOnUser(currentChatStatusEntry.username, "lb-picchat:toggleTyping", loggedInUsername, false)
            end
            currentChatStatusEntry.username = loggedInUsername
        end
        currentChatStatusEntry.typing = isTypingToggleBool
    end

    triggerClientEventOnUser(loggedInUsername, "lb-picchat:toggleInChat", chatPartnerUsername, inChatToggleBool)
    
    if isTypingUpdate ~= nil then
        triggerClientEventOnUser(loggedInUsername, "lb-picchat:toggleTyping", chatPartnerUsername, isTypingToggleBool)
    end
    
    debugprint("inChat: %s", inChatStatus)
    return true
end

local function clearChatStatus(username)
    local status = inChatStatus[username]
    if not status then
        return
    end

    triggerClientEventOnUser(status.username, "lb-picchat:toggleInChat", username, false)
    if status.typing then
        triggerClientEventOnUser(status.username, "lb-picchat:toggleTyping", username, false)
    end
    inChatStatus[username] = nil
end

registerCallbackWithAccountCheck(
    "toggleInChat",
    function(source, phoneNumber, loggedInUsername, chatPartnerUsername, inChatStatusToggle)
        updateChatStatus(chatPartnerUsername, loggedInUsername, inChatStatusToggle, nil)
        return true
    end
)

registerCallbackWithAccountCheck(
    "toggleTyping",
    function(source, phoneNumber, loggedInUsername, chatPartnerUsername, isTypingToggle)
        updateChatStatus(chatPartnerUsername, loggedInUsername, true, isTypingToggle)
        return true
    end
)

registerCallbackWithAccountCheck(
    "getChatStatus",
    function(source, phoneNumber, loggedInUsername, chatPartnerUsername)
        local status = inChatStatus[chatPartnerUsername]
        if status and status.username == loggedInUsername then
            return {
                inChat = true,
                typing = status.typing
            }
        end
        return false
    end,
    false
)

registerCallbackWithAccountCheck(
    "markPostsAsOpened",
    function(source, phoneNumber, recipientUsername, postIds, senderUsername)
        if not postIds or #postIds == 0 or not senderUsername then
            debugprint("markPostsAsOpened: Invalid data")
            return
        end

        local affectedRows = MySQL.update.await(
            "UPDATE lbpicchat_posts SET opened = 1, opened_at = CURRENT_TIMESTAMP WHERE recipient = ? AND opened = 0 AND id IN (?)",
            {recipientUsername, postIds}
        )
        debugprint("markPostsAsOpened: %d affected rows, success: %s", affectedRows, affectedRows > 0)

        if not (affectedRows > 0) then
            return false
        end

        local maxPostId = MySQL.scalar.await(
            "SELECT MAX(id) FROM lbpicchat_posts WHERE (recipient = ? AND sender = ?) OR (recipient = ? AND sender = ?)",
            {recipientUsername, senderUsername, senderUsername, recipientUsername}
        )
        if maxPostId then
            if contains(postIds, maxPostId) then
                MySQL.update(
                    "UPDATE lbpicchat_friends SET last_interaction_opened = 1, last_interaction_time = CURRENT_TIMESTAMP WHERE (username = ? AND friend = ?) OR (username = ? AND friend = ?)",
                    {recipientUsername, senderUsername, senderUsername, recipientUsername}
                )
                triggerClientEventOnUser(senderUsername, "lb-picchat:openedLastPost", recipientUsername)
            end
        end

        triggerClientEventOnUser(senderUsername, "lb-picchat:postsOpened", postIds)
        return affectedRows > 0
    end,
    false
)

registerCallbackWithAccountCheck(
    "sendMessage",
    function(source, phoneNumber, senderUsername, recipientUsername, messageContent, attachments)
        if attachments then
            messageContent = "<!ATTACHMENTS!>:" .. attachments
        end

        if not (recipientUsername and type(recipientUsername) == "string" and messageContent and type(messageContent) == "string" and #recipientUsername > 0 and #messageContent > 0) then
            return false
        end
        
        if messageContent then
            if exports["lb-phone"]:ContainsBlacklistedWord(source, messageContent) then
                Log(source, "error", L("LOGS.MESSAGE_BLACKLISTED_WORD"), {sender = senderUsername, recipient = recipientUsername, message = messageContent})
                return false
            end
        end

        local newPostId = MySQL.insert.await(
            "INSERT INTO lbpicchat_posts (sender, recipient, post_type, metadata) VALUES (?, ?, 'chat', ?)",
            {senderUsername, recipientUsername, messageContent}
        )
        if not newPostId then
            return false
        end

        MySQL.update(
            "UPDATE lbpicchat_friends SET last_interaction_type = 'chat', last_interaction_sender = ?, last_interaction_opened = 0, last_interaction_time = CURRENT_TIMESTAMP WHERE (username = ? AND friend = ?) OR (username = ? AND friend = ?)",
            {senderUsername, senderUsername, recipientUsername, recipientUsername, senderUsername}
        )

        triggerClientEventOnUser(recipientUsername, "lb-picchat:newMessage", {
            id = newPostId,
            sender = senderUsername,
            content = messageContent,
            attachments = attachments
        })

        local senderAccount = accountsCache[senderUsername]
        sendNotificationToAccount(recipientUsername, {
            title = L("NOTIFICATIONS.MESSAGE.TITLE", {name = senderAccount.name, message = messageContent}),
            content = L("NOTIFICATIONS.MESSAGE.CONTENT", {name = senderAccount.name, message = messageContent}),
            avatar = senderAccount.avatar
        })

        Log(source, "info", L("LOGS.SENT_MESSAGE"), {sender = senderUsername, recipient = recipientUsername, message = messageContent, attachments = attachments})
        return newPostId
    end,
    false
)

local function sendStory(source, username, link, metadata)
    local queryStart = "INSERT INTO lbpicchat_stories (username, link"
    local queryValues = ") VALUES (?, ?"
    local params = {username, link}

    if metadata then
        queryStart = queryStart .. ", metadata"
        queryValues = queryValues .. ", ?"
        table.insert(params, metadata)
    end
    queryValues = queryValues .. ")"
    local finalQuery = queryStart .. queryValues

    MySQL.insert(finalQuery, params, function(storyId)
        if not storyId then
            return
        end

        local account = accountsCache[username]
        if account then
            account.story = link
        end

        MySQL.update.await("UPDATE lbpicchat_accounts SET story_id = ? WHERE username = ?", {storyId, username})
        
        TriggerClientEvent("lb-picchat:newStory", -1, username, storyId, link)

        Log(source, "info", L("LOGS.ADDED_STORY"), {username = username, link = link, metadata = metadata})
    end)
end

registerCallbackWithAccountCheck(
    "sendPost",
    function(source, phoneNumber, senderUsername, recipients, link, isVideo, metadata)
        if not recipients or type(recipients) ~= "table" or #recipients == 0 then
            debugprint("No recipients for sendPost from %s", senderUsername)
            return false
        end

        if not link or type(link) ~= "string" then
            debugprint("No link provided for sendPost from %s", senderUsername)
            return false
        end

        if metadata then
            if exports["lb-phone"]:ContainsBlacklistedWord(source, metadata) then
                Log(source, "error", L("LOGS.POST_BLACKLISTED_WORD"), {sender = senderUsername, recipients = recipients, link = link, metadata = metadata})
                return false
            end
        end

        local sentToSelf = false
        for i = #recipients, 1, -1 do
            local recipient = recipients[i]
            if recipient == senderUsername then
                sentToSelf = true
                sendStory(source, senderUsername, link, metadata)
                table.remove(recipients, i)
            end
        end

        local pointsEarned = #recipients
        if sentToSelf then
            pointsEarned = pointsEarned + 1
        end

        if pointsEarned > 0 then
            local senderAccount = accountsCache[senderUsername]
            senderAccount.points = senderAccount.points + pointsEarned
            MySQL.update("UPDATE lbpicchat_accounts SET points = points + ? WHERE username = ?", {pointsEarned, senderUsername})
        end

        if #recipients == 0 then
            if sentToSelf then
                return true
            end
            debugprint("No recipients left after processing send to self")
            return false
        end

        local insertQueryStart = "INSERT INTO lbpicchat_posts (sender, recipient, post_type, link"
        local insertQueryValues = ") VALUES (?, ?, 'media', ?"
        if metadata then
            insertQueryStart = insertQueryStart .. ", metadata"
            insertQueryValues = insertQueryValues .. ", ?"
        end
        insertQueryValues = insertQueryValues .. ")"
        local finalInsertQuery = insertQueryStart .. insertQueryValues

        local updateFriendQuery = "UPDATE lbpicchat_friends SET last_interaction_type = ?, last_interaction_sender = ?, last_interaction_opened = 0, last_interaction_time = CURRENT_TIMESTAMP, points = points + 1 WHERE (username = ? AND friend = ?) OR (username = ? AND friend = ?)"
        local updateFriendParamsBatched = {}

        local senderAccount = accountsCache[senderUsername]
        local mediaType = isVideo and "video" or "photo"
        local notificationTitle = L("NOTIFICATIONS.SENT_MEDIA.TITLE", {name = senderAccount.name, mediaType = L("NOTIFICATIONS.SENT_MEDIA." .. mediaType:upper())})
        local notificationContent = L("NOTIFICATIONS.SENT_MEDIA.CONTENT", {name = senderAccount.name, mediaType = L("NOTIFICATIONS.SENT_MEDIA." .. mediaType:upper())})
        local notificationAvatar = senderAccount.avatar

        for i = 1, #recipients do
            local currentRecipient = recipients[i]
            
            sendNotificationToAccount(currentRecipient, {
                title = notificationTitle,
                content = notificationContent,
                avatar = notificationAvatar
            })

            local interactionType = isVideo and "video" or "image"
            table.insert(updateFriendParamsBatched, {
                interactionType,
                senderUsername,
                senderUsername, currentRecipient,
                currentRecipient, senderUsername
            })

            local postParams = {senderUsername, currentRecipient, link}
            if metadata then
                table.insert(postParams, metadata)
            end
            MySQL.insert(finalInsertQuery, postParams, function(postId)
                if postId then
                    triggerClientEventOnUser(currentRecipient, "lb-picchat:newPost", {
                        id = postId,
                        sender = senderUsername,
                        link = link,
                        metadata = metadata,
                        isVideo = isVideo
                    })
                end
            end)

            Citizen.CreateThreadNow(function()
                UpdateStreak(senderUsername, currentRecipient)
            end)
        end

        MySQL.update("UPDATE lbpicchat_accounts SET points = points + 1 WHERE username IN (?)", {recipients})
        
        MySQL.rawExecute(updateFriendQuery, updateFriendParamsBatched)

        Log(source, "info", L("LOGS.SENT_POST"), {sender = senderUsername, recipients = recipients, link = link, metadata = metadata})
        return true
    end,
    false
)

registerCallbackWithAccountCheck(
    "removeStory",
    function(source, phoneNumber, username, storyId)
        local affectedRows = MySQL.update.await("DELETE FROM lbpicchat_stories WHERE id = ? AND username = ?", {storyId, username})
        if not (affectedRows > 0) then
            return false
        end

        local account = accountsCache[username]
        local latestStory = MySQL.single.await("SELECT id, link FROM lbpicchat_stories WHERE username = ? ORDER BY id DESC LIMIT 1", {username})

        if not latestStory then
            account.story = nil
            MySQL.update("UPDATE lbpicchat_accounts SET story_id = NULL WHERE username = ?", {username})
        else
            if account.story ~= latestStory.link then
                account.story = latestStory.link
                MySQL.update("UPDATE lbpicchat_accounts SET story_id = ? WHERE username = ?", {latestStory.id, username})
            end
        end
        return true
    end,
    false
)

registerCallbackWithAccountCheck(
    "getStoryViewers",
    function(source, phoneNumber, username, storyId)
        return MySQL.query.await([[
            SELECT
                v.viewer AS username,
                a.display_name AS `name`,
                a.avatar AS avatar,
                v.viewed_at AS `timestamp`
            FROM
                lbpicchat_stories_views v
            LEFT JOIN
                lbpicchat_accounts a
                ON a.username = v.viewer
            WHERE
                v.story_id = ?
        ]], {storyId})
    end,
    {}
)

registerCallbackWithAccountCheck(
    "getStories",
    function(source, phoneNumber, viewerUsername, storyOwnerUsername)
        local viewsCountSelect = ""
        if storyOwnerUsername == viewerUsername then
            viewsCountSelect = ", (SELECT COUNT(1) FROM lbpicchat_stories_views WHERE story_id = s.id) AS views"
        end

        local query = string.format([[
            SELECT
                s.id,
                s.link,
                s.metadata,
                s.posted_at,
                v.viewer
                %s
            FROM
                lbpicchat_stories s
            LEFT JOIN lbpicchat_stories_views v
                ON v.story_id = s.id AND v.viewer = ?
            WHERE
                s.username = ?
        ]], viewsCountSelect)

        local stories = MySQL.query.await(query, {viewerUsername, storyOwnerUsername})

        for i = 1, #stories do
            local story = stories[i]
            story.viewed = (story.viewer ~= nil)
            story.viewer = nil

            if story.metadata then
                story.metadata = json.decode(story.metadata)
            else
                story.metadata = nil
            end
            
            story.timestamp = story.posted_at
            story.posted_at = nil
        end
        return stories
    end,
    {}
)

registerCallbackWithAccountCheck(
    "markStoriesAsViewed",
    function(source, phoneNumber, viewerUsername, storyIds, storyOwnerUsername)
        if not storyIds or #storyIds == 0 then
            debugprint("No stories viewed, not marking them as viewed")
            return false
        end

        if storyOwnerUsername == viewerUsername then
            debugprint("Cannot view own story: %s", viewerUsername)
            return false
        end

        local paramsBatched = {}
        local insertQuery = "INSERT IGNORE INTO lbpicchat_stories_views (viewer, poster, story_id) VALUES (?, ?, ?)"
        for i = 1, #storyIds do
            table.insert(paramsBatched, {viewerUsername, storyOwnerUsername, storyIds[i]})
        end

        MySQL.rawExecute(insertQuery, paramsBatched)
        return true
    end,
    false
)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    phoneNumberToUsernameMap = {}
    for username in pairs(accountsCache) do
        saveAccountAndRemoveFromCache(username)
    end
end)

RegisterNetEvent("lb-picchat:openedApp")
AddEventHandler("lb-picchat:openedApp", function()
    local playerSource = source
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerSource)
    if not phoneNumber then
        return
    end

    local username = phoneNumberToUsernameMap[phoneNumber]
    if not username then
        return
    end

    local account = accountsCache[username]
    if not account then
        return
    end

    if StartTrackingLocation then
        local settings = account.settings
        if settings and settings.showLocation and settings.liveUpdateLocation then
            StartTrackingLocation(username, playerSource, phoneNumber)
        end
    end
end)

RegisterNetEvent("lb-picchat:closedApp")
AddEventHandler("lb-picchat:closedApp", function()
    local playerSource = source
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerSource)
    if not phoneNumber then
        return
    end

    local username = phoneNumberToUsernameMap[phoneNumber]
    if not username then
        return
    end

    clearChatStatus(username)
end)

AddEventHandler("playerDropped", function()
    local playerSource = source
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerSource)
    if not phoneNumber then
        return
    end

    local username = phoneNumberToUsernameMap[phoneNumber]
    if not username then
        return
    end

    phoneNumberToUsernameMap[phoneNumber] = nil
    saveAccountAndRemoveFromCache(username)
    clearChatStatus(username)
end)

PerformHttpRequest("https://loaf-scripts.com/versions/", function(errorCode, resultData, headers)
    if resultData then
        print(resultData)
    end
end, "POST", json.encode({
    resource = "lb-picchat",
    version = GetResourceMetadata(GetCurrentResourceName(), "version", 0) or "0.0.0"
}), {["Content-Type"] = "application/json"})
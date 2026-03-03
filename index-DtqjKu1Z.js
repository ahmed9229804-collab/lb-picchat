MySQL.ready.await()

local function UpdateStreak(senderUsername, receiverUsername)
    debugprint("update streak", senderUsername, receiverUsername)

    local mysqlUpdateAwait = MySQL.update.await

    local query1 = "UPDATE lbpicchat_friends SET last_streak_sender = ? WHERE ((username = ? AND friend = ?) OR (username = ? AND friend = ?)) AND (last_streak_sender != ? OR last_streak_sender IS NULL)"
    local params1 = {
        senderUsername,
        senderUsername,
        receiverUsername,
        receiverUsername,
        senderUsername,
        senderUsername
    }
    local rowsAffected = mysqlUpdateAwait(query1, params1)

    if not (rowsAffected > 0) then
        return
    end

    local query2 = [[
        UPDATE
            lbpicchat_friends
        SET
            interaction_streak = interaction_streak + 1
        WHERE
            ((username = ? AND friend = ?) OR (username = ? AND friend = ?))
            AND DATEDIFF(CURRENT_TIMESTAMP, last_streak_time) > 0
    ]]
    local params2 = {
        senderUsername,
        receiverUsername,
        receiverUsername,
        senderUsername
    }
    mysqlUpdateAwait(query2, params2)

    local query3 = "UPDATE lbpicchat_friends SET last_streak_time = CURRENT_TIMESTAMP WHERE ((username = ? AND friend = ?) OR (username = ? AND friend = ?))"
    local params3 = {
        senderUsername,
        receiverUsername,
        receiverUsername,
        senderUsername
    }
    mysqlUpdateAwait(query3, params3)
end

UpdateStreak = UpdateStreak
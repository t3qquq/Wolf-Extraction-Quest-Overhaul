--- Client half of the extraction death rule.
---
--- The server decides what happens when a member dies mid run, but it cannot
--- carry either heavy rule out itself:
---
---   * Faction and SafeHouse only broadcast their member lists from
---     GameClient (Faction.java does not even import GameServer), so a
---     removePlayer() on a dedicated server changes server memory and never
---     reaches a single client.
---   * Spectator mode is client state by nature.
---
--- So the server sends the order and this file executes it. Vanilla lets any
--- member drop themselves from a faction with exactly this call (see
--- ISFactionUI:onQuitFaction), so nothing here needs admin rights.
---
--- Never sync any of this with sendPlayerExtraInfo(): the server's anti cheat
--- reads that as a Type 8 violation and kicks the player.

if not isClient() then return end

WQS_DeathRule = WQS_DeathRule or {}

local MODULE = "WQS_MP"

-- Keys the spectator keeps. Everything else is zeroed while spectating, which
-- is a whitelist on purpose: blocking individual actions means missing one.
local KEEP_KEYS = {
    ["Forward"] = true,
    ["Backward"] = true,
    ["Left"] = true,
    ["Right"] = true,
    ["Run"] = true,
    ["Sprint"] = true,
    ["Zoom in"] = true,
    ["Zoom out"] = true,
    ["Pause"] = true,
    ["Normal Speed"] = true,
    ["Fast Forward x1"] = true,
    ["Fast Forward x2"] = true,
    ["Fast Forward x3"] = true,
    ["Take screenshot"] = true,
    ["Toggle chat"] = true,
    ["Alt toggle chat"] = true,
    ["Switch chat stream"] = true,
    ["Enable voice transmit"] = true,
    ["Display FPS"] = true,
    ["Toggle Lua Debugger"] = true,
    ["ToggleLuaConsole"] = true,
}

WQS_DeathRule.Spectating = false
WQS_DeathRule.KeyMemo = nil

-- ##############################################################
-- key binding
-- ##############################################################

local function InhibitKeys()
    if WQS_DeathRule.KeyMemo then
        return
    end
    WQS_DeathRule.KeyMemo = {}
    for i, v in ipairs(keyBinding) do
        if v.key and v.key ~= 0 and v.value and not KEEP_KEYS[v.value] then
            WQS_DeathRule.KeyMemo[v.value] = v.key
            v.key = 0
            getCore():addKeyBinding(v.value, 0)
        end
    end
    print("WQS_MP spectate: key bindings inhibited")
end

local function RestoreKeys()
    if not WQS_DeathRule.KeyMemo then
        return
    end
    for i, v in ipairs(keyBinding) do
        if v.value and WQS_DeathRule.KeyMemo[v.value] then
            v.key = WQS_DeathRule.KeyMemo[v.value]
            getCore():addKeyBinding(v.value, v.key)
        end
    end
    WQS_DeathRule.KeyMemo = nil
    print("WQS_MP spectate: key bindings restored")
end

-- ##############################################################
-- spectator mode
-- ##############################################################

--- Sprite invisibility is a separate layer from setInvisible(): without it the
--- body still draws for other clients within a couple of tiles.
local function SetSpriteInvisible(player, on)
    local sprite = player:getSprite()
    if not sprite then
        return
    end
    local props = sprite:getProperties()
    if not props then
        return
    end
    if on then
        props:Set(IsoFlagType.invisible)
    else
        props:UnSet(IsoFlagType.invisible)
    end
end

function WQS_DeathRule.SetSpectate(on)
    local player = getPlayer()
    if not player then
        return
    end

    player:setCanSeeAll(on)
    player:setGodMod(on)
    player:setInvincible(on)
    player:setInvisible(on)
    -- IsoZombie:417 skips the whole attack branch when the target carries this
    player:setZombiesDontAttack(on)
    SetSpriteInvisible(player, on)

    -- walking through walls is loud in a shared run, so it is opt in
    if SandboxVars.WQS_SpectateNoClip_opt then
        player:setNoClip(on)
    end

    if on then
        InhibitKeys()
        removeInventoryUI(0)
    else
        RestoreKeys()
    end

    player:getModData().WQS_Spectate = on
    WQS_DeathRule.Spectating = on

    print("WQS_MP spectate " .. tostring(on) .. " user=" .. tostring(player:getUsername()))

    if on then
        player:Say(getText("IGUI_WQS_MP_SpectateOn"))
    end
end

--- A brand new character must never inherit spectator state, and a reconnect
--- must not leave a live player invisible. Both are cleared on the first tick
--- where the local player exists.
local function ClearStaleSpectate(player)
    if player ~= getSpecificPlayer(0) or not player:isLocalPlayer() then
        return
    end
    if player:getModData().WQS_Spectate and not WQS_DeathRule.Spectating then
        WQS_DeathRule.SetSpectate(false)
    end
    Events.OnPlayerUpdate.Remove(ClearStaleSpectate)
end
Events.OnPlayerUpdate.Add(ClearStaleSpectate)

-- ##############################################################
-- group kick
-- ##############################################################

--- Faction.setOwner() moves the outgoing owner into the member list before it
--- swaps, so the hand over has to happen before the removal or the dead owner
--- is never removable. Order is fixed.
local function LeaveFaction(player, successor)
    local username = player:getUsername()
    local faction = Faction.getPlayerFaction(player)
    if not faction then
        print("WQS_MP death rule: no faction to leave user=" .. tostring(username))
        return
    end

    if faction:isOwner(username) then
        if not successor then
            -- nobody left to hand it to; the wipe path destroys the session
            print("WQS_MP death rule: owner has no successor, kick skipped user=" ..
                tostring(username))
            return
        end
        faction:setOwner(successor)
        print("WQS_MP death rule: faction ownership handed to " .. tostring(successor))
    end

    faction:removePlayer(username)
    print("WQS_MP death rule: left faction user=" .. tostring(username))
end

--- SafeHouse.playerAllowed() is "players.contains(name) OR owner.equals(name)",
--- and addSafeHouse() puts the owner in both. So dropping the owner from the
--- member list alone changes nothing at all: they still pass the owner half of
--- the check. Ownership has to move first, same as the faction path.
local function LeaveSafehouse(player, successor)
    local username = player:getUsername()
    local safehouse = SafeHouse.hasSafehouse(player)
    if not safehouse then
        print("WQS_MP death rule: no safehouse to leave user=" .. tostring(username))
        return
    end

    if safehouse:getOwner() == username then
        if not successor then
            print("WQS_MP death rule: safehouse owner has no successor, kick skipped user=" ..
                tostring(username))
            return
        end
        -- setOwner() here is a plain assignment with no member bookkeeping, so
        -- make sure the successor is actually in the list. addPlayer() already
        -- guards against duplicates.
        safehouse:addPlayer(successor)
        safehouse:setOwner(successor)
        print("WQS_MP death rule: safehouse ownership handed to " .. tostring(successor))
    end

    safehouse:removePlayer(username)
    safehouse:syncSafehouse()
    print("WQS_MP death rule: left safehouse user=" .. tostring(username))
end

function WQS_DeathRule.LeaveGroup(mode, successor)
    local player = getPlayer()
    if not player then
        return
    end
    if mode == 2 then
        LeaveFaction(player, successor)
    elseif mode == 3 then
        LeaveSafehouse(player, successor)
    end
    player:Say(getText("IGUI_WQS_MP_DeathKicked"))
end

-- ##############################################################
-- transport
-- ##############################################################

local function OnServerCommand(module, command, args)
    if module ~= MODULE then
        return
    end
    if command == "EnterSpectate" then
        WQS_DeathRule.SetSpectate(true)
    elseif command == "LeaveGroup" then
        args = args or {}
        WQS_DeathRule.LeaveGroup(args.mode, args.successor)
    end
end
Events.OnServerCommand.Add(OnServerCommand)

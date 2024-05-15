local functions = {}
local logger = require("logging.logger")
local log = logger.new { name = "bsFunctions", logLevel = "NONE", logToConsole = true, }
-- local spellMaker = require("BeefStranger.spellMaker")
-- local effectMaker = require("BeefStranger.effectMaker")

functions.effect = require("BeefStranger.effectMaker")
functions.sound = require("BeefStranger.sounds")
functions.bsSound = require("BeefStranger.sounds").bsSound
functions.playSound = require("BeefStranger.playSound")
functions.spell = require("BeefStranger.spellMaker")

---@param toggle boolean Toggles debug for functions
function functions.debug(toggle)
    if toggle then
        log:setLogLevel("DEBUG")
        log:debug("Debug Enabled")
    end
end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------Timer---------------------------------
---@class timer
---@field dur number How long each iteration lasts
---@field iter number? Number of times it'll repeat
---@field cb function The function ran when duration is expired
---@param params timer
---@return mwseTimer timerId
--- `dur` - How long each iteration lasts
---
--- `iter` - *Optional* - Number of times it'll repeat
---
--- `cb` - The function ran when duration is expired
---
---     functions.timer{dur = 1, iter = 3, cb = function()}
function functions.timer(params)
    local timerId = timer.start{
            duration = params.dur,
            iterations = params.iter or 1,
            callback = params.cb,
    }
    return timerId
end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------onTick---------------------------------
---@param e tes3magicEffectTickEventData The tick event data
---@param action function The function to be inserted into the beginning spell state.
---Sets up all the triggers for an effect. Usually used at the end of the onTick function ex:
---
---     local function onEffectTick(e)
---         local function doThis()
---            this thing
---         end
---        *functions.onTick(e, doThis)*
---     end
function functions.onTick(e, action)
if e.effectInstance.state == tes3.spellState.working then
        e:trigger(); return
    elseif e.effectInstance.state == tes3.spellState.beginning then
        e:trigger();e:trigger()
        action(e)
    elseif e.effectInstance.state == tes3.spellState.ending then
        e.effectInstance.state = tes3.spellState.retired
    end
end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------effectTimer---------------------------------
--- Attempt to emulate vanilla effect timer.
---@param e tes3magicEffectTickEventData Used to pass eventData to timer for calculations
---@param callback function The function the timer will run
---Example:
---
---     bs.effectTimer(e, function ()
---         target.mobile:applyDamage { damage = 1, playerAttack = true }
---     end)
function functions.effectTimer(e, callback)
    local effect = #e.sourceInstance.sourceEffects > 0 and e.sourceInstance.sourceEffects[1] ---@type tes3effect
    local duration = effect and math.max(1, effect.duration) or 1
    local mag = e.effectInstance.effectiveMagnitude
    local iter = 0
    log:debug("effectTimer: mag = %s", mag)
    local timerId = timer.start({
        duration = 1 / mag,
        callback = function()
            iter = iter + 1
            log:debug("effectTimer: %s", iter)
            callback() --(table.unpack(args))
        end,
        iterations = duration * mag,
    })
    return timerId
end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------dmgTick---------------------------------
----Effect Timer to add damage per tick
---@class dmgTick
---@field damage number? Default: to 1 perTick. The amount of damage dealt perTick
---@field applyArmor boolean? Default: false. If armor should mitigate the incoming damage. If the player is the target, armor experience will be gained.
---@field resist tes3.effectAttribute? Optional. The resistance attribute that is applied to the damage. It can reduce damage or exploit weakness
---@field applyDifficulty boolean? Default: false. If the game difficulty modifier should be applied. Must be used with the playerAttack argument to apply the correct modifier.
---@field playerAttack boolean? Optional. If the attack came from the player. Used for difficulty calculation.
---@field doNotChangeHealth boolean? Default: false. If all armor effects except the health change should be applied. These include hit sounds, armor condition damage, and player experience gain from being hit.
---@param e tes3magicEffectTickEventData
---@param params dmgTick
---
---`Function to quickly add Damage = effectiveMagnitude * duration on timer lasting duration`
--- 
---     functions.dmgTick(e, {damage = 1})
---
---*`---Parameters---`*
--
---`damage` - The Damage applied each tick
--
---`applyArmor` - If armor mitigates
--
---`resist` - The attribute that resists this
--
---`applyDifficulty` - If the difficulty modifier is used
--
---`playerAttack` - If the attack came from the player
--
---`doNotChangeHealth` - If it shouldnt actually damage but still do armor effects
function functions.dmgTick(e, params) 
    if e.effectInstance.state == tes3.spellState.working then e:trigger() return end
    local ref = e.effectInstance.target
    local refHandle = tes3.makeSafeObjectHandle(ref) --Make safe handle
    local test2Id
    local iter = 1
    local function timerCallback()
        if refHandle and refHandle:valid() then
            log:debug("timerCallback - %s", iter); iter = iter + 1 --for debugging
            local mobile = refHandle:getObject() and refHandle:getObject().mobile --put safeObject into ref
            if not mobile then log:debug("not mobile") return end
            mobile:applyDamage({
                damage = params.damage or 1,
                applyArmor = params.applyArmor or false,
                resistAttribute = params.resist,
                applyDifficulty = params.applyDifficulty,
                playerAttack = params.playerAttack or true,
                doNotChangeHealth = params.doNotChangeHealth
            })

            if mobile.health.current <= 0 then
                test2Id:cancel()
                log:debug("target dead cancel timer setState to ending")
                e.effectInstance.state = tes3.spellState.ending --ending
            end
        end
    end

    if e.effectInstance.state == tes3.spellState.beginning then
        e:trigger() e:trigger()
        local mag = e.effectInstance.effectiveMagnitude
        test2Id = functions.effectTimer(e, timerCallback)
        log:debug("mag = %s", mag)
        e.effectInstance.state = tes3.spellState.working
    end

    if e.effectInstance.state == tes3.spellState.ending then
        e.effectInstance.state = tes3.spellState.retired
        log:debug("ending")
    end
end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------getEffect---------------------------------
--Took from OperatorJack--
---@param e tes3magicEffectCollisionEventData|tes3magicEffectTickEventData
---@param effectId tes3.effect
---Usage: 
--
---     functions.getEffect(e, tes3.effect.light)
---     functions.getEffect(e, 41) --Same as above but with number
--
---`Mainly used for spells you create`
--
---Vanilla ID's `↓`
function functions.getEffect(e, effectId)
    for i = 1, 8 do
        local effect = e.sourceInstance.sourceEffects[i]
        if effect ~= nil and effect.id == effectId then
            return effect
        end
    end
    return nil
end
------------------------------------------------------------------------------------------------------------------------------

---------------------------------duration---------------------------------
---@param e tes3magicEffectCollisionEventData|tes3magicEffectTickEventData The tick/collision data
---@param effectID tes3.effect The ID of the spell. Either the name or ID`(tes3.effect.light or 41)`
---@return integer duration The duration of the effect, will return 1 if no `duration`
---Usage:
--
---     local duration = functions.duration(e, tes3.effect.light)
--
---`returns duration of spell or 1 if the duration was 0`
--
---Vanilla ID's `↓`
function functions.duration(e, effectID)
    local duration = functions.getEffect(e, effectID) and math.max(1, functions.getEffect(e, effectID).duration) or 1
    return duration
end


------------------------------------------------------------------------------------------------------------------------------


---------------------------------RayCast---------------------------------
---@param maxDistance number RayCast from players eye, returns a reference
---@return tes3reference | nil 
---Usage:
--
---     local target = functions.rayCast(900)
--
---`Returns a reference`
--
---`Ignores player`
--
---`maxDistance` is in game units, if you want it in ft like spell radius is divide by 22.1
function functions.rayCast(maxDistance)
    local result = tes3.rayTest({
        position = tes3.getPlayerEyePosition(),
        direction = tes3.getPlayerEyeVector(),
        ignore = {tes3.player},
        maxDistance = maxDistance,
    })
    if result and result.reference then --if result is reference return it
        return result.reference
    else
        return nil
    end
end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------LinearInterpolation---------------------------------
-- local m = -9/150 -- slope m represents how much the base cost changes for each increase in the number of undead kills/Where undead kills maxes out
-- local c = 10 -- the max when above is negative? --baseCost 
-- local base = math.max(m * arkayData.kills + c, 1)
-- local base2 = math.max( -9/150 * arkayData.kills + 10, 1)
-- linear interpolation formula
-- posLinear -- local damage =                        math.min((2/150)   * tes3.player.data.arkay.kills + 1,  3)
--                                                          (1, 3, 150, tes3.player.data.arkay.kills)
-- negLinear -- tes3.getObject("test2").magickaCost = math.max((-24/150) * arkayData.kills + 25, 1)


--- 
--- functions.linearInter(10, 1, 150, tes3.player.data.arkay.kills, false)
---
--- start at 10, end at 1 when arkay.kills = 150, is negative (false)
---
--- functions.linearInter(1, 3, 150, tes3.player.data.arkay.kills, true)
---
--- start at 1, end at 3 when arkay.kills = 150, is a positive increase (true)
---
---comment
---@param base any The starting value
---@param max any The value it ends at
---@param progressCap any When the value of data hits this max will be the value
---@param data any Where progressCap gets its data
---@param positive boolean If true then returns a positive slope, negative if false
---@return number
function functions.linearInter(base, max, progressCap, data, positive)
    local slope = (max - base)/progressCap
    local result = (slope * data + base)
    if positive then
        return math.min(result, max)
    else
        return math.max(result, max)
    end
end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------Lerp (LinearInterpolation with funner name)---------------------------------
---@param base any The starting value
---@param max any The value it ends at
---@param progressCap any When the value of data hits this max will be the value
---@param data any Where progressCap gets its data
---@param isPositive boolean If true then returns a positive slope, negative if false
---@return number
---Usage:
--
---     local damage = functions.lerp(1, 3, 150, playerData.kills, true)
--
---`1 - is the starting value`
--
---`3 - is the end value`
--
---`150 - the cap, when kills in this example reaches 150, damage = 3, when its 0, damage = 1`
--
---`playerData.kills - can be anything, in this instance its player.data.kills, which keeps track of kills and increments starting value`
--
---`true - means the value is increasing, when false decreasing` `lerp(3, 1, 150, `playerData.kills, false)`
--
function functions.lerp(base, max, progressCap, data, isPositive)
    local slope = (max - base)/progressCap
    local result = (slope * data + base)
    if isPositive then
        return math.min(result, max)
    else
        return math.max(result, max)
    end
end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------Small Helper Functions---------------------------------
---Get onTick spells state
---@param e tes3magicEffectTickEventData
---@return tes3.spellState
function functions.state(e)
    return e.effectInstance.state
end
--------------------
--------------------
---Removes and Adds back the spell. Made for updating a spells cost after the player has it.
---@param ref tes3reference
---@param spell string
function functions.refreshSpell(ref, spell)
    tes3.removeSpell{reference = ref, spell = spell}
    tes3.addSpell{reference = ref, spell = spell}
end
--------------------
--------------------
---More convienent addSpell when you're just adding spell to a ref
---@param ref any Who to add the spell to
---@param spell string Spell Id
function functions.addSpell(ref, spell)
    tes3.addSpell{reference = ref, spell = spell}
end
--------------------
--------------------
function functions.bulkAddSpells(ref, spellTable)
    for _, spell in pairs(spellTable) do
        if not tes3.hasSpell{reference = ref, spell = spell.spellId} then
            tes3.addSpell{reference = ref, spell = spell.spellId}
        else
            log:debug("bullkAddSpells - Player already has %s, skipping", spell.spellId)
        end
    end
end
--------------------
---Adds the spell to the `ref` and sets them to sell spells
---@param ref string The id of the reference ex: "fargoth"
---@param spellId any The id of the spell ex: "fire bite"
---Usage:
--
---     functions.sellSpell("fargoth", "rallying touch")
function functions.sellSpell(ref, spellId)
    local seller = tes3.getReference(ref)
    if seller == tes3.player or seller == tes3.mobilePlayer then return end
    if seller.object.aiConfig.offersSpells == false then
        seller.object.aiConfig.offersSpells = true
        log:debug("%s now offersSpells", seller)
    end
    functions.addSpell(seller, spellId)
    log:debug("%s added to %s", spellId, seller)
end
--------------------
--------------------
---@param name string Name of the logger
---@param level mwseLoggerLogLevel? logLevel : Defaults to "DEBUG"
---Usage:
--
---     local log = functions.createLog("FunctionsLog", "TRACE")
---`    This creates a log with the name of "FunctionsLog" with a logLevel of "TRACE"`
--
---`Log Levels:`
function functions.createLog(name, level)
    if not level then level = "DEBUG" end
    local logging = require("logging.logger").new{ name = name, logLevel = level, logToConsole = true}

    return logging
end
--------------------
--------------------
---comment
---@param name string Name of the logger to load
---@return table
function functions.getLog(name)
    local logging = require("logging.logger").getLogger(name) or ""
    -- local trace = function (...) logging:trace(...) end
    -- local debug = function (...) logging:debug(...) end
    -- local info = function (...) logging:info(...) end
    -- local warn = function (...) logging:warn(...) end
    -- local error = function (...) logging:error(...) end

    -- return trace, debug, info, warn, error
    return
    {
    log = logging,
    trace = function (...) logging:trace(...) end,
    debug = function (...) logging:debug(...) end,
    info = function (...) logging:info(...) end,
    warn = function (...) logging:warn(...) end,
    error = function (...) logging:error(...) end,
    }
end
--------------------
--------------------
---Small helper function to handle keyUp event, includes a check for menuMode, not really faster but i wanted it.
---@param key string The Key to trigger it ex: "p" 
---@param func function The function you want to run on key press
function functions.keyUp(key, func)
    local function onLoad() --only register event when game is loaded
        local function keyAction() --needed for menuMode check
            if not tes3.menuMode() then
                func() --This is where the passed along function runs
            end
        end
        event.register("keyUp", keyAction, { filter = tes3.scanCode[key] })
    end
    event.register("loaded", onLoad) --Wait until game is loaded to register keyUp
end
--------------------

------------------------------------------------------------------------------------------------------------------------------


---------------------------------objectTypes in Table---------------------------------
---@type table Table to convert objectTypes inserted into its string
functions.objectTypeNames = {
    [1230259009] = "activator",
    [1212369985] = "alchemy",
    [1330466113] = "ammunition",
    [1095782465] = "apparatus",
    [1330467393] = "armor",
    [1313297218] = "birthsign",
    [1497648962] = "bodyPart",
    [1263488834] = "book",
    [1280066883] = "cell",
    [1396788291] = "class",
    [1414483011] = "clothing",
    [1414418243] = "container",
    [1095062083] = "creature",
    [1279347012] = "dialogue",
    [1330007625] = "dialogueInfo",
    [1380929348] = "door",
    [1212370501] = "enchantment",
    [1413693766] = "faction",
    [1414745415] = "gmst",
    [1380404809] = "ingredient",
    [1145979212] = "land",
    [1480938572] = "landTexture",
    [1129727308] = "leveledCreature",
    [1230390604] = "leveledItem",
    [1212631372] = "light",
    [1262702412] = "lockpick",
    [1178945357] = "magicEffect",
    [1129531725] = "miscItem",
    [1413693773] = "mobileActor",
    [1380139341] = "mobileCreature",
    [1212367181] = "mobileNPC",
    [1346584909] = "mobilePlayer",
    [1246908493] = "mobileProjectile",
    [1347637325] = "mobileSpellProjectile",
    [1598246990] = "npc",
    [1146242896] = "pathGrid",
    [1112494672] = "probe",
    [1397052753] = "quest",
    [1162035538] = "race",
    [1380336978] = "reference",
    [1313293650] = "region",
    [1095779666] = "repairItem",
    [1414546259] = "script",
    [1279871827] = "skill",
    [1314213715] = "sound",
    [1195658835] = "soundGenerator",
    [1279610963] = "spell",
    [1380143955] = "startScript",
    [1413567571] = "static",
    [1346454871] = "weapon",
}
------------------------------------------------------------------------------------------------------------------------------
functions.skills = {
    [0] = "block",
    [1] = "armorer",
    [2] = "mediumArmor",
    [3] = "heavyArmor",
    [4] = "bluntWeapon",
    [5] = "longBlade",
    [6] = "axe",
    [7] = "spear",
    [8] = "athletics",
    [9] = "enchant",
    [10] = "destruction",
    [11] = "alteration",
    [12] = "illusion",
    [13] = "conjuration",
    [14] = "mysticism",
    [15] = "restoration",
    [16] = "alchemy",
    [17] = "unarmored",
    [18] = "security",
    [19] = "sneak",
    [20] = "acrobatics",
    [21] = "lightArmor",
    [22] = "shortBlade",
    [23] = "marksman",
    [24] = "mercantile",
    [25] = "speechcraft",
    [26] = "handToHand",
}

---------------------------------spellStates in Table---------------------------------
---@type table
functions.stateId = {
    [0] = "preCast",
    [1] = "cast",
    [4] = "beginning",
    [5] = "working",
    [6] = "ending",
    [7] = "retired",
    [8] = "workingFortify",
    [9] = "endingFortify",
}

functions.stateName = {
    ["preCast"] = 0,
    ["cast"] = 1,
    ["beginning"] = 4,
    ["working"] = 5,
    ["ending"] = 6,
    ["retired"] = 7,
    ["workingFortify"] = 8,
    ["endingFortify"] = 9,
}

------------------------------------------------------------------------------------------------------------------------------




return functions

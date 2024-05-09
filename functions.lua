local functions = {}
local logger = require("logging.logger")
local log = logger.new { name = "bsFunctions", logLevel = "DEBUG", logToConsole = true, }
local spellMaker = require("BeefStranger.spellMaker")
local effectMaker = require("BeefStranger.effectMaker")

functions.effect = require("BeefStranger.effectMaker")
functions.sound = require("BeefStranger.sounds")
functions.playSound = require("BeefStranger.playSound")
functions.spell = require("BeefStranger.spellMaker")

---------------------------------Timer---------------------------------
---@class timer
---@field dur number How long each iteration lasts
---@field iter number? Number of times it'll repeat
---@field cb function The function ran when duration is expired
---@param params timer
---@return mwseTimer
--- `dur` - How long each iteration lasts
---
--- `iter` - *Optional* - Number of times it'll repeat
---
--- `cb` - The function ran when duration is expired
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
function functions.onTick(e, action)
    if e.effectInstance.state == tes3.spellState.working then e:trigger() return end

    if e.effectInstance.state == tes3.spellState["beginning"] then
        e:trigger() e:trigger()
        action(e)
    end

    if e.effectInstance.state == tes3.spellState.ending then
        e.effectInstance.state = tes3.spellState.retired
    end

end
------------------------------------------------------------------------------------------------------------------------------


---------------------------------effectTimer---------------------------------
--- Attempt to emulate vanilla effect timer.
---@param e tes3magicEffectTickEventData Used to pass eventData to timer for calculations
---@param callback function The function the timer will run
function functions.effectTimer(e, callback)
    -- local args = {...}
    local effect = #e.sourceInstance.sourceEffects > 0 and e.sourceInstance.sourceEffects[1] ---@type tes3effect
    local duration = effect and math.max(1, effect.duration) or 1
    local mag = e.effectInstance.effectiveMagnitude
    log:debug("functions.effectTimer mag = %s", mag)

    local timerId = timer.start({
        duration = 1 / mag,
        callback = function()
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
function functions.dmgTick(e, params) ---Function to quickly add Damage = effectiveMagnitude * duration on timer lasting duration
    if e.effectInstance.state == tes3.spellState.working then e:trigger() return end

    local ref = e.effectInstance.target
    local refHandle = tes3.makeSafeObjectHandle(ref) --Make safe handle
    local test2Id
    local iter = 1
    -- local mag

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


---------------------------------RayCast---------------------------------
---@param maxDistance number RayCast from players eye, returns a reference
---@return tes3reference | nil 
function functions.rayCast(maxDistance)
    local result = tes3.rayTest({
        position = tes3.getPlayerEyePosition(),
        direction = tes3.getPlayerEyeVector(),
        ignore = {tes3.player},
        maxDistance = maxDistance,
    })

    if result and result.reference then --if result is reference that has mobile data return mobile
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
return functions

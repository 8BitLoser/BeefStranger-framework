local functions = {}
local logger = require("logging.logger")
local log = logger.getLogger("Arkays Logger") or "Logger Not Found"



---@param callback function
---@param e tes3magicEffectTickEventData
function functions.timer(e, callback, ...) --duration, iterations, callback, ... | ... is to pass along tickeventdata ie: e.effectInstance.target.mobile
    local args = {...}
    local effect = #e.sourceInstance.sourceEffects > 0 and e.sourceInstance.sourceEffects[1] ---@type tes3effect
    local duration = effect and math.max(1, effect.duration) or 1
    local mag = e.effectInstance.effectiveMagnitude
    log:debug("functions.timer mag = %s", mag)

    local timerId = timer.start({
        duration = 1 / mag,
        callback = function()
            callback(table.unpack(args))
        end,
        iterations = duration * mag,
    })
    return timerId
end


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


return functions

--[[ function functions.timer(duration, iterations, callback, ...)
    local args = {...}
    local timerId = timer.start({
        duration = duration,
        callback = function()
            callback(table.unpack(args))
        end,
        iterations = iterations,
    })
    return timerId
end ]]

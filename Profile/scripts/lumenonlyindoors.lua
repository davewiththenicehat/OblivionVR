-- Require the configuration file for global settings.
require(".\\Config\\CONFIG")

------------------------------------------------------------------------------------
-- Helper section
------------------------------------------------------------------------------------
-- Alias for the UEVR API, providing access to various engine functionalities.
local api = uevr.api
-- Alias for UEVR VR parameters, likely containing VR-specific settings.
local vr = uevr.params.vr

--- Sets an integer value for a console variable (cvar).
-- @param cvar The name of the console variable as a string.
-- @param value The integer value to set.
function set_cvar_int(cvar, value)
    -- Get the console manager from the UEVR API.
    local console_manager = api:get_console_manager()

    -- Find the console variable by its name.
    local var = console_manager:find_variable(cvar)
    -- If the variable is found, set its integer value.
    if(var ~= nil) then
        var:set_int(value)
    end
end

-------------------------------------------------------------------------------
-- hook_function
-- Hooks a UEVR function to inject custom logic before or after its execution.
--
-- @param class_name The name of the class containing the function, e.g., "Class /Script.GunfireRuntime.RangedWeapon".
-- @param function_name The name of the function to hook.
-- @param native True if the function is a native (C++) function, false otherwise.
-- @param prefn The function to run *before* the original function. Pass nil to not use.
-- @param postfn The function to run *after* the original function. Pass nil to not use.
-- @param dbgout True to print debug outputs, false to suppress them.
--
-- Example:
--     hook_function("Class /Script/GunfireRuntime.RangedWeapon", "OnFireBegin", true, nil, gun_firingbegin_hook, true)
--
-- @return True on success, false on failure.
-------------------------------------------------------------------------------
local function hook_function(class_name, function_name, native, prefn, postfn, dbgout)
    -- Print debug message if dbgout is true.
    if(dbgout) then print("LumensOnlyIndoors.lua: LumensOnlyIndoors.lua: Hook_function for ", class_name, function_name) end
    local result = false
    -- Find the UObject class by its name.
    local class_obj = uevr.api:find_uobject(class_name)
    -- If the class object is found.
    if(class_obj ~= nil) then
        if dbgout then print("LumensOnlyIndoors.lua: hook_function: found class obj for", class_name) end
        -- Find the specific function within the class.
        local class_fn = class_obj:find_function(function_name)
        -- If the function is found.
        if(class_fn ~= nil) then
            if dbgout then print("LumensOnlyIndoors.lua: hook_function: found function", function_name, "for", class_name) end
            -- If the function is native, set the native function flag (0x400).
            if (native == true) then
                class_fn:set_function_flags(class_fn:get_function_flags() | 0x400)
                if dbgout then print("LumensOnlyIndoors.lua: hook_function: set native flag") end
            end

            -- Apply the pre and post hooks to the function pointer.
            class_fn:hook_ptr(prefn, postfn)
            result = true
            if dbgout then print("LumensOnlyIndoors.lua: hook_function: set function hook for", prefn, "and", postfn) end
        end
    end

    return result
end

-------------------------------------------------------------------------------
-- Logs to the log.txt file.
--
-- @param message The string message to log.
-------------------------------------------------------------------------------
local function log_info(message)
    uevr.params.functions.log_info(message)
end

-- Find the GameEngine class object.
local game_engine_class = api:find_uobject("Class /Script/Engine.GameEngine")

--- Callback function that runs when a level change begins (fades to black).
-- This function disables Lumen global illumination.
-- @param fn The function object being hooked.
-- @param obj The object instance the function belongs to.
-- @param locals A table containing the function's local variables.
-- @param result The original return value of the function (not used here).
local function FadeToBlackBegin(fn, obj, locals, result)
    -- Only proceed if Lumen indoors is enabled in the configuration.
    if not Enable_Lumen_Indoors then return end
    print("LumensOnlyIndoors.lua: level change begin, disabling lumen\n")
    -- Set r.DynamicGlobalIlluminationMethod to 0 (disables DGI).
    set_cvar_int("r.DynamicGlobalIlluminationMethod", 0)
    -- Set r.Lumen.DiffuseIndirect.Allow to 0 (disables Lumen diffuse indirect lighting).
    set_cvar_int("r.Lumen.DiffuseIndirect.Allow", 0)
end

--- Callback function that runs when fading back into the game (level load complete).
-- This function checks if the current world is an interior or exterior and adjusts Lumen settings accordingly.
-- @param fn The function object being hooked.
-- @param obj The object instance the function belongs to.
-- @param locals A table containing the function's local variables.
-- @param result The original return value of the function (not used here).
local function FadeToGameBegin(fn, obj, locals, result)
    -- Only proceed if Lumen indoors is enabled in the configuration.
    if not Enable_Lumen_Indoors then return end
    print("LumensOnlyIndoors.lua: Fade to game\n")
    -- Get the first GameEngine object instance.
    local game_engine = UEVR_UObjectHook.get_first_object_by_class(game_engine_class)

    -- Get the GameViewport from the GameEngine.
    local viewport = game_engine.GameViewport
    if viewport == nil then
        print("LumensOnlyIndoors.lua: Viewport is nil")
        return
    end
    -- Get the World from the Viewport.
    local world = viewport.World

    if world == nil then
        print("LumensOnlyIndoors.lua: World is nil")
        return
    end

    -- Get the full name of the current world.
    local WorldName = world:get_full_name()

    -- Check if the world name contains "World/", which typically indicates an exterior map.
    if not WorldName:find("World/") then
        print("LumensOnlyIndoors.lua: Interior, enabling lumen")
        -- If it's an interior, enable Lumen.
        set_cvar_int("r.DynamicGlobalIlluminationMethod", 1)
        set_cvar_int("r.Lumen.DiffuseIndirect.Allow", 1)
    else
        print("LumensOnlyIndoors.lua: Exterior, leaving lumen disabled.")
        -- If it's an exterior, leave Lumen disabled (as it was set in FadeToBlackBegin).
    end
end

-- Hook the "OnFadeToBlackBeginEventReceived" function in "VLevelChangeData" class.
-- This hook triggers the FadeToBlackBegin function when a fade to black event occurs.
hook_function("Class /Script/Altar.VLevelChangeData", "OnFadeToBlackBeginEventReceived", false, nil, FadeToBlackBegin, false)
-- Hook the "OnFadeToGameBeginEventReceived" function in "VLevelChangeData" class.
-- This hook triggers the FadeToGameBegin function when a fade to game event occurs.
hook_function("Class /Script/Altar.VLevelChangeData", "OnFadeToGameBeginEventReceived", false, nil, FadeToGameBegin, false)
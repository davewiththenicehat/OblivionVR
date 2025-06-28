-- UEHelper.lua (Refactored for Readability)

local api = uevr.api
local params = uevr.params
local callbacks = params.sdk.callbacks

-- Global variables initialized once at script load time.
-- These might become stale if the player/pawn changes during runtime
-- unless explicitly updated elsewhere or passed as arguments.
local pawn = api:get_local_pawn(0)
local vr = uevr.params.vr


--------------------------------------------------------------------------------
-- UObject/Class Finding Utility Functions
--------------------------------------------------------------------------------

--- Finds a required UObject by its name. Errors if not found.
-- @param name string The full name of the UObject to find.
-- @return UObject The found UObject.
function find_required_object(name)
    local obj = uevr.api:find_uobject(name)
    if not obj then
        error("Cannot find " .. name)
        return nil
    end
    return obj
end

--- Finds the class default object for a given class name.
-- @param name string The full name of the UClass to find.
-- @return UObject The class default object.
function find_static_class(name)
    local c = find_required_object(name)
    return c:get_class_default_object()
end

--- Finds the first UObject of a specified class.
-- @param className string The name of the UClass to search for.
-- @param includeDefault boolean (optional) Whether to include default objects in the search. Defaults to false.
-- @return UObject The first found UObject of the class, or nil.
function find_first_of(className, includeDefault)
    if includeDefault == nil then includeDefault = false end
    local class = find_required_object(className)
    if class ~= nil then
        return UEVR_UObjectHook.get_first_object_by_class(class, includeDefault)
    end
    return nil
end

--- Searches for a required UObject by its full name without using a cache.
-- @param class UClass The UClass to search within.
-- @param full_name string The full name of the object to match.
-- @return UObject The found UObject, or nil.
function find_required_object_no_cache(class, full_name)
    local matches = class:get_objects_matching(false)

    for i, obj in ipairs(matches) do
        if obj ~= nil and obj:get_full_name() == full_name then
            return obj
        end
    end
    return nil
end

--- Searches an array of sub-objects for an item whose FName contains a partial string.
-- Returns the first matching item found.
-- @param ObjArray table An array of UObjects.
-- @param string_partial string The partial string to search for in the FName.
-- @return UObject The first matching UObject, or nil if not found.
function SearchSubObjectArrayForObject(ObjArray, string_partial)
    local FoundItem = nil
    for i, InvItems in ipairs(ObjArray) do
        if string.find(InvItems:get_fname():to_string(), string_partial) then
            FoundItem = InvItems
            break -- Found the first match, exit loop
        end
    end
    return FoundItem
end


--------------------------------------------------------------------------------
-- Input Handling Functions (VR to Key & XInput Helpers)
--------------------------------------------------------------------------------

-- VR to key functions
--- Sends a key press event (down or up) for a given key value.
-- @param key_value string The key value (e.g., "LeftMouse", "E").
-- @param key_up boolean True for key up event, false for key down event.
function SendKeyPress(key_value, key_up)
    local key_up_string = "down"
    if key_up == true then 
        key_up_string = "up"
    end
    api:dispatch_custom_event(key_value, key_up_string)
end

--- Sends a key down event for a given key value.
-- @param key_value string The key value.
function SendKeyDown(key_value)
    SendKeyPress(key_value, false)
end

--- Sends a key up event for a given key value.
-- @param key_value string The key value.
function SendKeyUp(key_value)
    SendKeyPress(key_value, true)
end

--- Masks a string to only contain digits and optionally a leading negative sign.
-- @param text string The input string.
-- @return string The masked string.
function PositiveIntegerMask(text)
    return text:gsub("[^%-%d]", "")
end

-- XInput Helpers
--- Checks if a specific button is pressed in the XInput state.
-- @param state table The XInput state table.
-- @param button number The XInput button constant (e.g., XINPUT_GAMEPAD_A).
-- @return boolean True if the button is pressed, false otherwise.
function isButtonPressed(state, button)
    return state.Gamepad.wButtons & button ~= 0
end

--- Checks if a specific button is NOT pressed in the XInput state.
-- @param state table The XInput state table.
-- @param button number The XInput button constant.
-- @return boolean True if the button is not pressed, false otherwise.
function isButtonNotPressed(state, button)
    return state.Gamepad.wButtons & button == 0
end

--- Sets a specific button as pressed in the XInput state.
-- @param state table The XInput state table (modified in place).
-- @param button number The XInput button constant.
function pressButton(state, button)
    state.Gamepad.wButtons = state.Gamepad.wButtons | button
end

--- Sets a specific button as unpressed in the XInput state.
-- @param state table The XInput state table (modified in place).
-- @param button number The XInput button constant.
function unpressButton(state, button)
    state.Gamepad.wButtons = state.Gamepad.wButtons & ~(button)
end


--------------------------------------------------------------------------------
-- Global State Variables
--------------------------------------------------------------------------------

-- General game state flags
current_scope_state = false
isSprinting = false
isDriving = false
isMenu = false
isWeaponDrawn = false
isBow = false
isRiding = false

-- Gamepad input values (updated dynamically)
ThumbLX = 0
ThumbLY = 0
ThumbRX = 0
ThumbRY = 0
LTrigger = 0
RTrigger = 0
rShoulder = false
lShoulder = false
lThumb = false
rThumb = false
Abutton = false
Bbutton = false
Xbutton = false
Ybutton = false
SelectButton = false

--------------------------------------------------------------------------------
-- Dynamic Helper Functions (Update Status)
--------------------------------------------------------------------------------

--- Updates the `isBow` status based on the player's equipped weapon.
-- @param pawn UObject The player's pawn object.
local function UpdateBowStatus(pawn)
    isBow = false
    if isRiding == false then -- Check if not riding
        if pawn and pawn.WeaponsPairingComponent and pawn.WeaponsPairingComponent.WeaponActor then
            if pawn.WeaponsPairingComponent.WeaponActor.MainSkeletalMeshComponent ~= nil then
                if string.find(pawn.WeaponsPairingComponent.WeaponActor:get_fname():to_string(), "Bow") then
                    isBow = true
                end
            end
        end
    end
end

--- Updates the `isRiding` status based on the pawn's name.
-- @param Pawn UObject The player's pawn object.
local function UpdateRidingStatus(Pawn) -- Note: 'Pawn' capitalized in signature
    isRiding = false
    if Pawn and string.find(Pawn:get_fname():to_string(), "Horse") then
        isRiding = true
    end
end

--- Updates the global gamepad input variables from the XInput state.
-- @param state table The XInput state table.
function UpdateInput(state)
    -- Read Gamepad stick input
    ThumbLX = state.Gamepad.sThumbLX
    ThumbLY = state.Gamepad.sThumbLY
    ThumbRX = state.Gamepad.sThumbRX
    ThumbRY = state.Gamepad.sThumbRY
    LTrigger = state.Gamepad.bLeftTrigger
    RTrigger = state.Gamepad.bRightTrigger
    rShoulder = isButtonPressed(state, XINPUT_GAMEPAD_RIGHT_SHOULDER)
    lShoulder = isButtonPressed(state, XINPUT_GAMEPAD_LEFT_SHOULDER)
    lThumb = isButtonPressed(state, XINPUT_GAMEPAD_LEFT_THUMB)
    rThumb = isButtonPressed(state, XINPUT_GAMEPAD_RIGHT_THUMB)
    Abutton = isButtonPressed(state, XINPUT_GAMEPAD_A)
    Bbutton = isButtonPressed(state, XINPUT_GAMEPAD_X) -- Note: B and X are inverted in your setup
    Xbutton = isButtonPressed(state, XINPUT_GAMEPAD_B) -- Note: B and X are inverted in your setup
    Ybutton = isButtonPressed(state, XINPUT_GAMEPAD_Y)
end

--- Updates the `isMenu` status based on mouse cursor visibility.
-- @param Player UObject The player controller object.
local function UpdateMenuStatus(Player)
    if Player and Player.bShowMouseCursor then
        isMenu = true
    else
        isMenu = false
    end
end

--- Updates the `isWeaponDrawn` status based on the pawn's combat stance.
-- @param pawn UObject The player's pawn object.
local function UpdateCombatStanceStatus(pawn)
    if pawn == nil then return end
    if pawn.bInCombatStance then
        isWeaponDrawn = true
    else
        isWeaponDrawn = false
    end
end

--- Updates the `isSprinting` status based on left shoulder button and left thumbstick Y input.
local function UpdateSprintStatus()
    if lShoulder and ThumbLY >= 28000 then 
        isSprinting = true
    end
    if ThumbLY < 15000 then
        isSprinting = false
    end
    -- Note: If ThumbLY is between 15000 and 28000 (and lShoulder is not pressed),
    -- isSprinting will retain its previous value.
end


--------------------------------------------------------------------------------
-- UEVR SDK Callbacks
--------------------------------------------------------------------------------

uevr.sdk.callbacks.on_xinput_get_state(
    function(retval, user_index, state)
        local dpawn = api:get_local_pawn(0) -- Get pawn locally for this tick

        -- UpdateDriveStatus(dpawn) -- This function is commented out and not defined.

        -- Read Gamepad stick input
        -- if PhysicalDriving then -- 'PhysicalDriving' is not defined in this script.
            UpdateInput(state)
        -- end
    end
)

uevr.sdk.callbacks.on_pre_engine_tick(
    function(engine, delta)
        local dpawn = api:get_local_pawn(0)      -- Get pawn locally for this tick
        local Player = api:get_player_controller(0) -- Get player controller locally for this tick
        -- local PMesh = pawn.FirstPersonSkeletalMeshComponent -- Commented out

        UpdateRidingStatus(dpawn)
        UpdateMenuStatus(Player)
        UpdateCombatStanceStatus(dpawn) 
        UpdateBowStatus(dpawn)
        UpdateSprintStatus()
    end
)
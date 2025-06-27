-- Require the UEHelper subsystem, which provides utility functions for interacting with Unreal Engine objects and XInput.
require(".\\Subsystems\\UEHelper")

local api = uevr.api

--[[
	Default UEVR control mapping
		
		Dpad left  -> up.....move forward
		Dpad left  -> down...move backward
		Dpad left  -> right..strafe right
		Dpad left  -> left...strafe left
		Dpad left  -> press..sprint
		Dpad right -> up.....camera tilt up
		Dpad right -> down...camera tilt down
		Dpad right -> right..character turn right
		Dpad right -> left...character turn left
		Dpad right -> press..Change view (first or third person)

		y, jump
		x, stow weapon
		b, crouch
		a, activate (like pick things up or open doors)

		left grip, weapon quick menu
		right grip, cast spell
		left tripper, block
		right trigger, attack

	Button mapping inherited from Subsystems\UEHelper.lua
		Function UpdateInput updates these mappings each uevr.sdk.callbacks.on_xinput_get_state call

		ThumbLX = state.Gamepad.sThumbLX
		ThumbLY = state.Gamepad.sThumbLY
		ThumbRX = state.Gamepad.sThumbRX
		ThumbRY = state.Gamepad.sThumbRY
		LTrigger= state.Gamepad.bLeftTrigger
		RTrigger= state.Gamepad.bRightTrigger
		rShoulder= isButtonPressed(state, XINPUT_GAMEPAD_RIGHT_SHOULDER)
		lShoulder= isButtonPressed(state, XINPUT_GAMEPAD_LEFT_SHOULDER)
		lThumb   = isButtonPressed(state, XINPUT_GAMEPAD_LEFT_THUMB)
		rThumb   = isButtonPressed(state, XINPUT_GAMEPAD_RIGHT_THUMB)
		Abutton  = isButtonPressed(state, XINPUT_GAMEPAD_A)
		Bbutton  = isButtonPressed(state, XINPUT_GAMEPAD_B)
		Xbutton  = isButtonPressed(state, XINPUT_GAMEPAD_X)
		Ybutton  = isButtonPressed(state, XINPUT_GAMEPAD_Y)

]]

-- Global variable to track the state of the Quick Menu. This needs to be global so other scripts (like RadialQuickMenu) can access its state.
QuickMenu = false 

-- Local variable to track if the B button was not pressed after the menu was exited.
local BbuttonNotPressedAfterMenu = false

-- Local variable to track the sprint state. (Note: this variable is declared but not explicitly used in the provided snippet to control sprint directly;
-- sprint logic is primarily handled in UEHelper's UpdateSprintStatus and the remapping here).
local SprintState = false

local controller_map_reference = {
    ["rShoulder"] = XINPUT_GAMEPAD_RIGHT_SHOULDER,
    ["lShoulder"] = XINPUT_GAMEPAD_LEFT_SHOULDER,
    ["lThumb"]    = XINPUT_GAMEPAD_LEFT_THUMB,
    ["rThumb"]    = XINPUT_GAMEPAD_RIGHT_THUMB,
    ["Abutton"]   = XINPUT_GAMEPAD_A,
    ["Xbutton"]   = XINPUT_GAMEPAD_B,  -- B and X are inverted
    ["Bbutton"]   = XINPUT_GAMEPAD_X,  -- ^
    ["Ybutton"]   = XINPUT_GAMEPAD_Y
}

--[[
controlleraction_options table:
activate: Abutton
weapon quick menu: lShoulder
crouch: None
attack: RTrigger
jump: None
sprint: lThumb
block: LTrigger
stow weapon: Xbutton
change view: rThumb
cast spell: rShoulder

Button pressed: rShoulder
default_button_action: cast spell
user_mapped_button_for_action: Bbutton
Unpressing: 512
adding button to buttons press table: 16384
        1: 16384
xinput_button_needing_press:16384
]]

-- Map default buttons in the game to actions
local default_uevr_action_controller_map = {
    lThumb = "sprint",
    rThumb = "change view",
    Ybutton = "jump", -- This is right thumb up in the UEVR profile
    Xbutton = "crouch", -- This is right thumb down in the UEVR profile
    Bbutton = "stow weapon", 
    Abutton = "activate",
    lShoulder = "weapon quick menu",
    rShoulder = "cast spell",
    LTrigger = "block",
    RTrigger = "attack"
}

-- map the actions to keys now
local uevr_action_to_button_controller_map = {}
for key, value in pairs(default_uevr_action_controller_map) do
    uevr_action_to_button_controller_map[value] = key
end

-- Callback function for intercepting and modifying XInput gamepad states.
-- This function is called every time the gamepad state is updated.
uevr.sdk.callbacks.on_xinput_get_state(
    function(retval, user_index, state)

        --[[
        --load settings from the config table
        for _, game_action_name in pairs(default_uevr_action_controller_map) do
            controller_action_options[game_action_name] = config_table[game_action_name]
        end
        for key, value in pairs(controller_action_options) do
            controller_button_to_actions_map[value] = key
        end
        ]]

        -- Game is in the game menu
        if isMenu then

            -- remap B and X buttons when in the game menu
            if Bbutton then unpressButton(state, XINPUT_GAMEPAD_B) end
            if Xbutton then unpressButton(state, XINPUT_GAMEPAD_X) end
            if Bbutton then pressButton(state, XINPUT_GAMEPAD_X) end
            if Xbutton then pressButton(state, XINPUT_GAMEPAD_B) end

        else -- game is playing, not in a game menu

            local buttons_to_press = {}   -- To collect XInput constants of buttons that should be pressed

            -- Loop through all the buttons we are allowing players to remap
            for pressed_button_name, pressed_xinput_instance in pairs(controller_map_reference) do
                -- The current button we are looping through has been pressed by the player.
                if isButtonPressed(state, pressed_xinput_instance) then

                    -- Get the default action for this physically pressed button
                    local default_action_for_button = default_uevr_action_controller_map[pressed_button_name]

                    -- If there's a default action associated with this button
                    if default_action_for_button then
                        -- Get the user's chosen button NAME for this default action from CONFIG.lua
                        action_player_wants = controller_button_to_actions_map[pressed_button_name]
                        local user_mapped_button_name_for_action = controller_action_options[action_player_wants]

                        -- Check if the user has remapped this action to a *different* button name
                        if default_action_for_button ~= pressed_button_name then
                            -- User has remapped it.
                            -- 1. Unpress the physically pressed button
                            for action_name, button_name in pairs(default_uevr_action_controller_map) do
                                print ("\t"..action_name..": "..button_name)
                            end
                            unpressButton(state, pressed_xinput_instance)

                            -- 2. Determine the XInput constant for the button the user *wants* pressed
                            button_name_player_wants_pressed = uevr_action_to_button_controller_map[action_player_wants]
                            local target_xinput_instance = controller_map_reference[button_name_player_wants_pressed]

                            -- Make sure the target button is not "None" and is a valid XInput constant
                            if target_xinput_instance and user_mapped_button_name_for_action ~= "None" then
                                table.insert(buttons_to_press, target_xinput_instance)
                            end
                        end
                    end
                end
            end

            -- Then, apply the presses
            for _, xinput_to_press in ipairs(buttons_to_press) do
                pressButton(state, xinput_to_press)
            end

            -- if the right thumb pad was pressed (beyond the deadzone) up jump
            if ThumbRY > 30000 then
                pressButton(state, XINPUT_GAMEPAD_Y)  -- press the jump key
            end

            -- if the right thumb pad was pressed (beyond the deadzone) up jump
            if ThumbRY < -30000 then
                pressButton(state, XINPUT_GAMEPAD_B)  -- press the crouch key
            end
        end

        -- This block prevents taking over stick input if the in-game menu is open or the player is riding.
        if not isMenu and not isRiding then
            -- If not sprinting, zero out the Left Thumbstick X and Y input.
            -- This effectively stops player movement if not sprinting.
            if not isSprinting then
                state.Gamepad.sThumbLX = 0
                state.Gamepad.sThumbLY = 0
            end
        end

    end
)
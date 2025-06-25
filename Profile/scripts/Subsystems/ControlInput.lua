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
    rShoulder = XINPUT_GAMEPAD_RIGHT_SHOULDER,
    lShoulder = XINPUT_GAMEPAD_LEFT_SHOULDER,
    lThumb    = XINPUT_GAMEPAD_LEFT_THUMB,
    rThumb    = XINPUT_GAMEPAD_RIGHT_THUMB,
    Abutton   = XINPUT_GAMEPAD_A,
    Bbutton   = XINPUT_GAMEPAD_B,
    Xbutton   = XINPUT_GAMEPAD_X,
    Ybutton   = XINPUT_GAMEPAD_Y
}

-- invert B and X on oculus
controller_map_reference["Bbutton"] = XINPUT_GAMEPAD_X
controller_map_reference["Xbutton"] = XINPUT_GAMEPAD_B

-- in oculus
-- XINPUT_GAMEPAD_B is the X button
-- XINPUT_GAMEPAD_X is the XINPUT_GAMEPAD_B

-- A is the A button
-- rShoulder is the rShoulder
-- lShoulder is the lShoulder
-- lThumb is the lThumb
-- rThumb is the rThumb
-- x is the 
-- y is the

local default_uevr_action_controller_map = {
    lThumb = "sprint",
    rThumb = "change view",
    Ybutton = "jump", -- This is normally thumb right up
    Xbutton = "stow weapon", -- This is normally thumb right down
    Bbutton = "crouch",
    Abutton = "activate",
    lShoulder = "weapon quick menu",
    rShoulder = "cast spell",
    LTrigger = "block",
    RTrigger = "attack"
}

-- Callback function for intercepting and modifying XInput gamepad states.
-- This function is called every time the gamepad state is updated.
uevr.sdk.callbacks.on_xinput_get_state(
    function(retval, user_index, state)

        if isButtonPressed(state, XINPUT_GAMEPAD_X) then
            print ("controlleraction_options table:")
            for action_name, button_name in pairs(controller_action_options) do
                print (action_name..": "..button_name)
            end
        end

        -- Game is in the game menu
        if isMenu then

            if Bbutton then unpressButton(state, XINPUT_GAMEPAD_B) end
            if Xbutton then unpressButton(state, XINPUT_GAMEPAD_X) end
            if Bbutton then pressButton(state, XINPUT_GAMEPAD_X) end
            if Xbutton then pressButton(state, XINPUT_GAMEPAD_B) end

        else -- game is playing, not in a game menu

            local button_presses_needed = {}

            for button_name, xinput_button_instance in pairs(controller_map_reference) do 
                -- The button we are looping through has been pressed by the player.
                if isButtonPressed(state, xinput_button_instance) then
                    default_button_action = default_uevr_action_controller_map[button_name]
                    user_mapped_button_for_action = controller_action_options[default_button_action]
                    -- If the user has mapped a different action for this button.
                    if user_mapped_button_for_action ~= button_name then
                        unpressButton(state, xinput_button_instance) -- stop pressing the button
                        -- Add an instance of the button the user would like this action mapped
                        -- to the button_presses_needed table.
                        -- Don't press the button now. The loop is not done.
                        table.insert(button_presses_needed, controller_map_reference[user_mapped_button_for_action])
                    end
                end
            end

            --loop throug button_presses_needed and press the buttons
            for _, xinput_button_needing_press in ipairs(button_presses_needed) do
                pressButton(state, xinput_button_needing_press)
            end

            
            --[[
            -- Check if the Y button is pressed and the Quick Menu is not currently active.
            if Ybutton and QuickMenu == false then
                -- Unpress the physical Y button to prevent its default action.
                unpressButton(state, XINPUT_GAMEPAD_Y)
                -- Trigger the "QuickMenuInput_Pressed" action on the player controller.
                api:get_player_controller():QuickMenuInput_Pressed()
                -- Set QuickMenu to true to indicate it's now active.
                QuickMenu = true
            -- If the Y button is not pressed.
            elseif not Ybutton then
                -- If the Quick Menu was previously active.
                if QuickMenu == true then
                    -- Trigger the "QuickMenuInput_Released" action on the player controller.
                    api:get_player_controller():QuickMenuInput_Released()
                    -- Set QuickMenu to false as it's no longer active.
                    QuickMenu = false
                end
            end
            
            -- If the Y button is pressed (after the QuickMenu logic above, this might be a re-press or for other actions).
            if Ybutton then
                -- Unpress the physical Y button.
                unpressButton(state, XINPUT_GAMEPAD_Y)
                -- (Commented out: potentially would have pressed the Right Shoulder button)
                --pressButton(state,XINPUT_GAMEPAD_RIGHT_SHOULDER)
            end

            -- If the B button is not pressed, set BbuttonNotPressedAfterMenu to true.
            -- This acts as a flag to ensure the B button remapping only happens once after release.
            if not Bbutton then
                BbuttonNotPressedAfterMenu = true
            end

            -- If the X button is pressed.
            if Xbutton then
                -- (Commented out: XbuttonNotPressedAfterMenu was a potential flag, but not used)
                --XbuttonNotPressedAfterMenu=true
                -- Unpress the physical X button.
                unpressButton(state, XINPUT_GAMEPAD_X)
                -- Press the Right Shoulder button, effectively remapping X to Right Shoulder.
                pressButton(state, XINPUT_GAMEPAD_RIGHT_SHOULDER)
            end

            -- If the Right Shoulder button is pressed.
            if rShoulder then
                -- Unpress the physical Right Shoulder button. This means the Right Shoulder's default action is consumed.
                unpressButton(state, XINPUT_GAMEPAD_RIGHT_SHOULDER)
            end

            -- If the B button is pressed AND the BbuttonNotPressedAfterMenu flag is true.
            if Bbutton and BbuttonNotPressedAfterMenu then
                -- Unpress the physical B button.
                unpressButton(state, XINPUT_GAMEPAD_B)
                -- Press the X button, effectively remapping B to X.
                pressButton(state, XINPUT_GAMEPAD_X)
            end

            -- If the Left Thumbstick button (L3) is pressed.
            if lThumb then
                -- Unpress the physical Left Thumbstick button.
                unpressButton(state, XINPUT_GAMEPAD_LEFT_THUMB)
                -- (Commented out: potentially would have pressed the Left Shoulder button)
                --pressButton(state,XINPUT_GAMEPAD_LEFT_SHOULDER)
            end

            -- If the Left Shoulder button (L1 or Left Grip) is pressed.
            if lShoulder then
                -- Unpress the physical Left Shoulder button. This means the Left Shoulder's default action is consumed.
                unpressButton(state, XINPUT_GAMEPAD_LEFT_SHOULDER)
                -- Press the Left Thumbstick button, effectively remapping Left Shoulder to Left Thumbstick (often used for sprint).
                pressButton(state, XINPUT_GAMEPAD_LEFT_THUMB)
            end
            ]]--

            -- If the Right Thumbstick Y-axis is pushed significantly up.
            if ThumbRY > 30000 then
                -- Press the Y button. This remaps a strong upward Right Thumbstick push to the Y button.
                pressButton(state, XINPUT_GAMEPAD_Y)
            end

            -- If the Right Thumbstick Y-axis is pulled significantly down.
            if ThumbRY < -30000 then
                -- Press the B button. This remaps a strong downward Right Thumbstick pull to the B button.
                pressButton(state, XINPUT_GAMEPAD_B)
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
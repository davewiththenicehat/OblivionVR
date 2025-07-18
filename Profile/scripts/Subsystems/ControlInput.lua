--[[

    RadialQuickmenu.lua
        creates a on_pre_engine_tick event to handle slowing time if the quick menu is open.

    UEHelper.lua
        contain a on_pre_engine_tick even to control a variable isSprinting.
        isSprinting is true if the player pawn is sprinting and is used in a few scripts.

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
		x, crouch
		b, stow weapon
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

-- Require the UEHelper subsystem, which provides utility functions for interacting with Unreal Engine objects and XInput.
require(".\\Subsystems\\UEHelper")

local api = uevr.api

-- Global variable to track the state of the Quick Menu. This needs to be global so other scripts (like RadialQuickMenu) can access its state.
QuickMenu = false 

-- Local variable to track if the B button was not pressed after the menu was exited.
local BbuttonNotPressedAfterMenu = false
local MenuExitedUnpressBButton = false

controller_map_reference = {
    ["rShoulder"] = XINPUT_GAMEPAD_RIGHT_SHOULDER,
    ["lShoulder"] = XINPUT_GAMEPAD_LEFT_SHOULDER,
    ["lThumb"]    = XINPUT_GAMEPAD_LEFT_THUMB,
    ["rThumb"]    = XINPUT_GAMEPAD_RIGHT_THUMB,
    ["Abutton"]   = XINPUT_GAMEPAD_A,
    ["Xbutton"]   = XINPUT_GAMEPAD_B,  -- B and X are inverted
    ["Bbutton"]   = XINPUT_GAMEPAD_X,  -- ^
    ["Ybutton"]   = XINPUT_GAMEPAD_Y
}

-- Map default buttons in the game to actions
default_uevr_action_controller_map = {
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
uevr_action_to_button_controller_map = {}
for key, value in pairs(default_uevr_action_controller_map) do
    uevr_action_to_button_controller_map[value] = key
end

-- this will record if the quick menu is currently active.
radial_quick_menu_active = false

-- Callback function for intercepting and modifying XInput gamepad states.
-- This function is called every time the gamepad state is updated.
uevr.sdk.callbacks.on_xinput_get_state(
    function(retval, user_index, state)

        -- --- Quick Menu Deactivation Logic (moved outside the loop and modified) ---
        -- Find the button name and XInput constant currently mapped to "weapon quick menu" in user config.
        local current_quick_menu_mapped_button_name = controller_action_options["weapon quick menu"]
        local current_quick_menu_xinput = controller_map_reference[current_quick_menu_mapped_button_name]
        -- If the quick menu is open
        -- and the the script successfully retreived the "current_quick_menu_xinput"
        --   (This is an instance of the button the player mapped for the quick menu)
        -- and the button the player mapped for the quick menu is NOT being pressed
        -- This means the user has released the button that opened the quick menu.
        if radial_quick_menu_active and current_quick_menu_xinput and not isButtonPressed(state, current_quick_menu_xinput) then
            api:get_player_controller():QuickMenuInput_Released()  -- stop the quick menu
            radial_quick_menu_active = false  -- record that the player is not longer in the quick menu
        end
        -- --- End Quick Menu Deactivation Logic ---

        -- --- Start sprint deactivation logic ---
        -- The current button the user has mapped for springing
        local current_sprint_button_name = controller_action_options["sprint"]
        -- Get a reference for the xinput object that the user wants to map the sprint button to
        local current_sprint_xinput = controller_map_reference[current_sprint_button_name]
        if isSprinting  -- If the player is currently sprinting
           and current_sprint_xinput  -- there is a good controller map
           and isButtonNotPressed(state, current_sprint_xinput) then -- but button the user mapped for springing is not pressed
            isSprinting = false
        end
        -- --- End sprint deactivation logic ---


        -- Game is in the game menu
        if isMenu then

            -- First, ensure both XINPUT_GAMEPAD_B and XINPUT_GAMEPAD_X are unpressed in the 'state'
            -- This gives us a clean slate to apply our desired mapping without native interference.
            unpressButton(state, XINPUT_GAMEPAD_B)
            unpressButton(state, XINPUT_GAMEPAD_X)

            -- The X and B buttons are revered in UEVR for Obilvion
            -- Correct that while in the game menu.
            if Xbutton then
                pressButton(state, XINPUT_GAMEPAD_B)
                -- Resolve issue where B button in pressed when exiting menu
                -- forcing an unwanted press of the B button.
                MenuExitedUnpressBButton = true
            end

            -- The X and B buttons are revered in UEVR for Obilvion
            -- Correct that while in the game menu.
            if Bbutton then
                pressButton(state, XINPUT_GAMEPAD_X)
            end


        else -- game is playing, not in a game menu

            local buttons_to_press = {}   -- To collect XInput constants of buttons that should be pressed
            local quick_menu_button_pressed = false

            if MenuExitedUnpressBButton then
                unpressButton(state, XINPUT_GAMEPAD_B)
                MenuExitedUnpressBButton = false
            end


            -- load button remapping from the config table
            for _, game_action_name in pairs(default_uevr_action_controller_map) do
                controller_action_options[game_action_name] = config_table[game_action_name]
            end
            -- Create a table that maps actions to buttons
            for key, value in pairs(controller_action_options) do
                controller_button_to_actions_map[value] = key
            end

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
                            -- Unpress the physically pressed button
                            unpressButton(state, pressed_xinput_instance)

                            -- If this is a quick menu request
                            if action_player_wants == "weapon quick menu" then
                                quick_menu_button_pressed = true
                                if not radial_quick_menu_active then
                                    api:get_player_controller():QuickMenuInput_Pressed()
                                    radial_quick_menu_active = true
                                end
                                -- we are done with logic for this single button
                                -- go to the next button for this same engine tick
                                goto next_button_in_loop
                            end

                            -- if the player is sprinting
                            if action_player_wants == "sprint" then
                                isSprinting = true
                            end

                            -- Determine the XInput constant for the button the user *wants* pressed
                            button_name_player_wants_pressed = uevr_action_to_button_controller_map[action_player_wants]
                            local target_xinput_instance = controller_map_reference[button_name_player_wants_pressed]

                            -- Make sure the target button is not "None" and is a valid XInput constant
                            if target_xinput_instance and user_mapped_button_name_for_action ~= "None" then
                                -- add the button to the table of buttons that will be pressed
                                table.insert(buttons_to_press, target_xinput_instance)
                            end

                        end
                    end
                end
                
                ::next_button_in_loop:: -- Label for `goto`

            end

            -- Apply the presses
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

    end
)
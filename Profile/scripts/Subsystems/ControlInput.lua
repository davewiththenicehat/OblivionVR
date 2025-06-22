-- Require the UEHelper subsystem, which provides utility functions for interacting with Unreal Engine objects and XInput.
require(".\\Subsystems\\UEHelper")

-- Global variable to track the state of the Quick Menu. This needs to be global so other scripts (like RadialQuickMenu) can access its state.
QuickMenu = false 

-- Local variable to track if the B button was not pressed after the menu was exited.
local BbuttonNotPressedAfterMenu = false

-- Local variable to track the sprint state. (Note: this variable is declared but not explicitly used in the provided snippet to control sprint directly;
-- sprint logic is primarily handled in UEHelper's UpdateSprintStatus and the remapping here).
local SprintState = false

-- Callback function for intercepting and modifying XInput gamepad states.
-- This function is called every time the gamepad state is updated.
uevr.sdk.callbacks.on_xinput_get_state(
    function(retval, user_index, state)

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

        -- This block of code executes only when the in-game menu (not the Quick Menu) is NOT active.
        if isMenu == false then
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
        -- If the in-game menu IS active, reset the BbuttonNotPressedAfterMenu flag.
        else
            BbuttonNotPressedAfterMenu = false
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
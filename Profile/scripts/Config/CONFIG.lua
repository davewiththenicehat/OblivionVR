local functions = uevr.params.functions

-- Preferences for the UEVR profile.
local check_uevr_version = true
local include_header = true

-- Static variables used for displaying header information in the UI.
local config_filename = "main-config.json"
local title = "Oblivion Remastered VR Mod Settings"
local author = "Pande4360"
local profile_name = "6dof Attached Items Profile (Righthand Aiming)"

-- Variables for UEVR version checking.
local required_uevr_commit_count = nil
local uevr_version = nil

-- List of all possible input options for dropdowns.
controller_input_options = {
    None = "None", -- Option for no mapping
    ThumbLX = "ThumbLX",
    ThumbLY = "ThumbLY",
    ThumbRX = "ThumbRX",
    ThumbRY = "ThumbRY",
    LTrigger = "LTrigger",
    RTrigger = "RTrigger",
    rShoulder = "rShoulder",
    lShoulder = "lShoulder",
    lThumb = "lThumb",
    rThumb = "rThumb",
    Abutton = "Abutton",
    Bbutton = "Bbutton",
    Xbutton = "Xbutton",
    Ybutton = "Ybutton",
}

--[[
    Global table to manage actions in the game that can be controlled by the controller.
    Save what controller button the action is mapped to.
    This table creates the default controller button each action gets mapped to.
]]--
controller_action_options = {
    ["sprint"] = "lShoulder",
    ["change view"] = "rThumb",
    ["jump"] = "None", -- This is normally thumb right up
    ["crouch"] = "None", -- This is normally thumb right down
    ["stow weapon"] = "Bbutton",
    ["activate"] = "Abutton",
    ["weapon quick menu"] = "Ybutton",
    ["cast spell"] = "Xbutton",
    ["block"] = "LTrigger",
    ["attack"] = "RTrigger",
}

-- Check if UEVR version check is enabled in preferences.
if check_uevr_version then
    -- Set the required commit count for version compatibility.
    required_uevr_commit_count = 1343
    -- Get the current UEVR version string.
    uevr_version = functions.get_tag_long() .. "+" .. functions.get_commit_hash()
end

-- Table to hold JSON file paths.
local json_files = {}

-- Initial configuration table with default settings for various mod features.
config_table = {
    Movement = 1, -- 1 for Head-based movement, other values might correspond to controller-based.
    Snap_Turn = false,
    Enable_Lumen_Indoors = false,
    Faster_Projectiles = false,
    Visible_Helmet = true,--(currently not wokring) -- Flag for helmet visibility (not currently functional).
    EnableHolster = true,
    Holster_Haptic_Feedback = true,
    Sword_Sideways_Is_Block = false,
    First_Person_Riding = true,
    Extra_Block_Range = 0,
    Melee_Power = 700,
    ReticleAlwaysOn =true,
    UI_Follows_View =true,
    DarkerDarks=false,
    RadialQuickMenu=true,
    ManageLighting=true,
    --HandIndex=2
    --isRhand = true
}

-- add controller input actions to config table
for game_action_name, game_action_value in pairs(controller_action_options) do
    config_table[game_action_name] = game_action_value
end

-- Search for the configuration file.
json_files = fs.glob(config_filename)

-- If the configuration file does not exist, create it with default settings.
if #json_files == 0 then
    json.dump_file(config_filename, config_table, 4)
end

-- Load the configuration from the file.
local re_read_table = json.load_file(config_filename)

-- Assert that the re-read table matches the initial config_table (for debugging/validation).
for _, key in ipairs(config_table) do
    assert(re_read_table[key] == config_table[key], key .. "is not the same")
end

-- Update the main config_table with values loaded from the file (this allows user-saved settings to persist).
for key, value in pairs(re_read_table) do
    config_table[key] = value
end

-- Assign global configuration variables based on the loaded config_table.
-- These variables are likely used throughout other scripts to control mod behavior.
if config_table.Movement == 1 then
    HeadBasedMovementOrientation = true
else
    HeadBasedMovementOrientation = false
end

SnapTurn = config_table.Snap_Turn
Enable_Lumen_Indoors = config_table.Enable_Lumen_Indoors
Faster_Projectiles = config_table.Faster_Projectiles
VisibleHelmet = config_table.Visible_Helmet
EnableHolster = config_table.EnableHolster
HolsterHapticFeedback = config_table.Holster_Haptic_Feedback
FirstPersonRiding = config_table.First_Person_Riding
SwordSidewaysIsBlock = config_table.Sword_Sideways_Is_Block
ExtraBlockRange = config_table.Extra_Block_Range
MeleePower = config_table.Melee_Power
ReticleAlwaysOn = config_table.ReticleAlwaysOn
UIFollowsView = config_table.UI_Follows_View
DarkerDarks=config_table.DarkerDarks
ManageLighting=config_table.ManageLighting
RadialQuickMenu=config_table.RadialQuickMenu
--isRhand = config_table.isRhand -- Commented out, likely not in use or for a feature not fully implemented.

-- Function to check and display UEVR version compatibility in the UI.
local function uevr_version_check()
    imgui.text("UEVR Version Check: ")
    imgui.same_line()
    -- Compare current UEVR commit count with the required one.
    if functions.get_total_commits() == required_uevr_commit_count then
        imgui.text_colored("Success", 0xFF00FF00) -- Green color for success.
    elseif functions.get_total_commits() > required_uevr_commit_count then
        imgui.text_colored("Newer", 0xFF00FF00) -- Green color for newer version.
        imgui.text("UEVR Version: " .. uevr_version)
        imgui.same_line()
        imgui.text("UEVR Build Date: " .. functions.get_build_date())
    elseif functions.get_total_commits() < required_uevr_commit_count then
        imgui.text_colored("Failed - Older", 0xFF0000FF) -- Red color for older version.
        imgui.text("UEVR Version: " .. uevr_version)
        imgui.same_line()
        imgui.text("UEVR Build Date: " .. functions.get_build_date())
    end
end

-- Function to create and display the main header in the UEVR UI.
local function create_header()
    imgui.text(title)
    imgui.text("By: " .. author)
    imgui.same_line()
    imgui.text("Profile: " .. profile_name)
   -- imgui.same_line()
    --imgui.text("Version: " .. profile_version) -- Commented out version display.

    -- Include UEVR version check if enabled.
    if check_uevr_version then
        uevr_version_check()
    end
    imgui.new_line()
end

-- Function to create a dropdown UI element for configuration.
local function create_dropdown(label_name, key_name, values)
    -- `imgui.combo` returns `changed` (boolean) and `new_value` (selected index).
    local changed, new_value = imgui.combo(label_name, config_table[key_name], values)

    if changed then
        -- Update the config_table with the new value and save it to the JSON file.
        config_table[key_name] = new_value
        json.dump_file(config_filename, config_table, 4)
        return new_value
    else
        return config_table[key_name]
    end
end

-- Function to create a checkbox UI element for boolean configuration.
local function create_checkbox(label_name, key_name)
    -- `imgui.checkbox` returns `changed` (boolean) and `new_value` (checked state).
    local changed, new_value = imgui.checkbox(label_name, config_table[key_name])

    if changed then
        -- Update the config_table with the new value and save it to the JSON file.
        config_table[key_name] = new_value
        json.dump_file(config_filename, config_table, 4)
        return new_value
    else
        return config_table[key_name]
    end
end

-- Function to create an integer slider UI element for numerical configuration.
local function create_slider_int(label_name, key_name, min, max)
    -- `imgui.slider_int` returns `changed` (boolean) and `new_value` (slider value).
    local changed, new_value = imgui.slider_int(label_name, config_table[key_name], min, max)

    if changed then
        -- Update the config_table with the new value and save it to the JSON file.
        config_table[key_name] = new_value
        json.dump_file(config_filename, config_table, 4)
        return new_value
    else
        return config_table[key_name]
    end
end

-- Callback function that is called when the UEVR UI is drawn.
uevr.sdk.callbacks.on_draw_ui(function()
    -- Include the header if enabled.
    if include_header then
        create_header()
    end

    -- Display the paths of loaded JSON config files (for debugging/info).
    for _, file in ipairs(json_files) do
        imgui.text(file)
    end
    
    imgui.text("Movement")
    -- Create dropdown for Movement Based On.
    local movement_values = {"Head", "Right Controller", "Left Controller"}
    local movement = create_dropdown("Movement Based On", "Movement", movement_values)
    -- Update HeadBasedMovementOrientation based on dropdown selection.
    if movement == 1 then
        HeadBasedMovementOrientation = true
    else
        HeadBasedMovementOrientation = false
    end

    -- Create checkbox for Snap Turn.
    SnapTurn = create_checkbox("Snap Turn", "Snap_Turn")
    imgui.new_line()

    imgui.text("Features")
    
    -- Create options for the 'Script UI' section in the UEVR settings menu.
    UIFollowsView = create_checkbox("UI Follows View", "UI_Follows_View")
    RadialQuickMenu = create_checkbox("Motion Controlled Radial Quick Menu", "RadialQuickMenu")
    Enable_Lumen_Indoors = create_checkbox("Enable Lumen Indoors", "Enable_Lumen_Indoors")
    Faster_Projectiles = create_checkbox("Faster Projectiles", "Faster_Projectiles")
    --ReticleAlwaysOn = create_checkbox("Reticle Always On", "Reticle Always On") -- Commented out, likely for a non-functional feature.
    -- VisibleHelmet = create_checkbox("Helmet Visibility", "Visible_Helmet") -- Commented out, already handled above and stated as not working.
    EnableHolster=create_checkbox("Enable Holster", "EnableHolster")
    HolsterHapticFeedback = create_checkbox("Holster Haptic Feedback (Required Enable Holster checked)", "Holster_Haptic_Feedback")
    FirstPersonRiding = create_checkbox("First Person Horse Riding", "First_Person_Riding")
    SwordSidewaysIsBlock = create_checkbox("Hold Sword Sideways To Block", "Sword_Sideways_Is_Block")
    --isRhand = create_checkbox("Right Hand Mode", "isRhand") -- Commented out, likely for a non-functional feature.
    DarkerDarks=create_checkbox("Darker interiors and nights (Requires: Manage lighting checked)", "DarkerDarks") 
    ManageLighting=create_checkbox("Manage lighting (Restart required on uncheck)", "ManageLighting") 
    ExtraBlockRange = create_slider_int("Extra Block Range (in cm)", "Extra_Block_Range", 0, 50)
    MeleePower = create_slider_int("Melee Power (swing intensity)", "Melee_Power", 0, 1500)

    imgui.separator() -- Visual separator for the new section
    imgui.text("Control Mapping")  -- Show message to UEVR UI
    for game_action_name, _ in pairs(controller_action_options) do  -- Loop through all the controller manageable game actions
        -- Create a UEVR UI drop down box for this controller action, save changes in config table if changes are made.
        local game_action_value = create_dropdown(game_action_name, game_action_name, controller_input_options)
        -- update the global controller options table with the value from UEVR menu.
        controller_action_options[game_action_name] = game_action_value
    end
    imgui.separator() -- Visual separator for the new section

end)

-- DEBUG VALUES, to test to fix some potential issues:
-- 1. Collision Capsule: try increase Half Height first. If you start floating before solving the issue, go back and increase capsRad, CapsRad is important to kept low as possible for melee to work as intended. 
CapsuleHalfHeightWhenMoving= 97  -- Vanilla=90, when not moving it's 90
CapsuleRadWhenMoving= 30.480       -- Vanilla=30, when not moving it's 7.93

-- Not functional / potentially deprecated:
isRhand = true    
isLeftHandModeTriggerSwitchOnly = true
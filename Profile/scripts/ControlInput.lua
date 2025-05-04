require(".\\Subsystems\\UEHelper")
local api = uevr.api
local QuickMenu=false
uevr.sdk.callbacks.on_xinput_get_state(
function(retval, user_index, state)


if Ybutton and lShoulder and QuickMenu==false then
	unpressButton(state,XINPUT_GAMEPAD_Y)
	api:get_player_controller():Quick7Input_Pressed()
	QuickMenu=true
elseif not Ybutton or not lShoulder then
	if QuickMenu== true then
		api:get_player_controller():Quick7Input_Released()
		QuickMenu=false
	end
end
if isMenu==false then
	if Ybutton then
		unpressButton(state,XINPUT_GAMEPAD_Y)
		--pressButton(state,XINPUT_GAMEPAD_RIGHT_SHOULDER)
	end
	if Xbutton then
		unpressButton(state,XINPUT_GAMEPAD_X)
		pressButton(state,XINPUT_GAMEPAD_RIGHT_SHOULDER)
	end
	if rShoulder then
		unpressButton(state,XINPUT_GAMEPAD_RIGHT_SHOULDER)
	end
	if Bbutton then
		unpressButton(state,XINPUT_GAMEPAD_B)
		pressButton(state,XINPUT_GAMEPAD_X)
	end

	if lThumb then
	unpressButton(state,XINPUT_GAMEPAD_LEFT_THUMB)
	--pressButton(state,XINPUT_GAMEPAD_LEFT_SHOULDER)
	end
	if lShoulder then
		unpressButton(state,XINPUT_GAMEPAD_LEFT_SHOULDER)
		pressButton(state,XINPUT_GAMEPAD_LEFT_THUMB)
	end
	
	if ThumbRY > 30000 then
		pressButton(state,XINPUT_GAMEPAD_Y)
	end
	if ThumbRY < -30000 then
		pressButton(state,XINPUT_GAMEPAD_B)
	end
end
end)
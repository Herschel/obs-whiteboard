--[[
    OBS Whiteboard
    v1.1 by Mike Welsh and contributors
    MIT License (see LICENSE.md for details)
    https://github.com/Herschel/obs-whiteboard
--]]

version     = "1.1"
obs         = obslua
hotkey_id   = obs.OBS_INVALID_HOTKEY_ID
texture 	= nil
blank		= true
needs_clear	= false

package.path = package.path .. ";" .. script_path() .. "packages/?.lua"

bit = require("bit")
winapi = require("winapi")
require("winapi.cursor")
require("winapi.keyboard")
require("winapi.window")
require("winapi.winbase")

print("OBS Whiteboard v" .. version)

source_def = {}
source_def.id = "whiteboard"
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW)

source_def.get_name = function()
    return "Whiteboard"
end

source_def.create = function(source, settings)
    local data = {}
    data.line = obs.gs_image_file()
    data.cap = obs.gs_image_file()
    data.mouse_pos = nil
    data.canvas_width = 0
    data.canvas_height = 0
    blank = true

    image_source_load(data.line, script_path() .. "assets/line.png")
    image_source_load(data.cap, script_path() .. "assets/cap.png")

    return data
end

source_def.destroy = function(data)
    obs.obs_enter_graphics()
    obs.gs_image_file_free(data.line)
    obs.gs_image_file_free(data.cap)
    obs.gs_texture_destroy(data.texture)
    texture = nil
    obs.obs_leave_graphics()
end

function script_description()
    return "Adds a whiteboard."
end

-- A function named script_load will be called on startup
function script_load(settings)
	hotkey_id = obs.obs_hotkey_register_frontend("whiteboard.clear", "Clear Whiteboard", clear)
	if hotkey_id == nil then
		hotkey_id = obs.OBS_INVALID_HOTKEY_ID
	end
	local hotkey_save_array = obs.obs_data_get_array(settings, "whiteboard.clear")
	obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "whiteboard.clear", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

function create_canvas_texture(data, width, height)
    obs.obs_enter_graphics()
    if texture then
        obs.gs_texture_destroy(data.texture)
        texture = nil
    end
    texture = obs.gs_texture_create(width, height, obs.GS_RGBA, 1, nil, obs.GS_RENDER_TARGET)
    data.texture = texture
    data.canvas_width = width
    data.canvas_height = height
    print("Created new whiteboard canvas (" .. width .. "x" .. height .. ")")

    obs.obs_leave_graphics()
end

source_def.video_tick = function(data, dt)
    -- Check for canvas resized
    local video_info = obs.obs_video_info()
    if obs.obs_get_video_info(video_info) and
        (not data.texture or data.canvas_width ~= video_info.base_width or data.canvas_height ~= video_info.base_height)
    then
        create_canvas_texture(data, video_info.base_width, video_info.base_height)
    end

    if not data.texture or data.canvas_width == 0 or data.canvas_height == 0 then
        return
    end

	if needs_clear then
		local prev_render_target = obs.gs_get_render_target()
	    local prev_zstencil_target = obs.gs_get_zstencil_target()

	    obs.gs_set_render_target(texture, nil)
	    obs.gs_viewport_push()
	    obs.gs_set_viewport(0, 0, data.canvas_width, data.canvas_height)

	    obs.obs_enter_graphics()
	    obs.gs_set_render_target(texture, nil)
	    obs.gs_clear(obs.GS_CLEAR_COLOR, obs.vec4(), 1.0, 0)

	    obs.gs_viewport_pop()
	    obs.gs_set_render_target(prev_render_target, prev_zstencil_target)

	    obs.obs_leave_graphics()

	    blank = true
	    needs_clear = false
	end

    local mouse_down = winapi.GetAsyncKeyState(winapi.VK_LBUTTON)
    if mouse_down then
        local mouse_pos = winapi.GetCursorPos()
        if data.mouse_pos == nil then
            data.mouse_pos = mouse_pos
        end

        local window = winapi.GetForegroundWindow()
        local window_name = winapi.WCS(32)
        winapi.InternalGetWindowText(window, window_name)
        if string.find(winapi.mbs(window_name), "Projector") then
            winapi.ScreenToClient(window, mouse_pos)

            local window_rect = winapi.GetClientRect(window)
            
            local canvas_width = data.canvas_width
            local canvas_height = data.canvas_height
            local canvas_aspect = canvas_width / canvas_height

            local window_width = window_rect.right - window_rect.left
            local window_height = window_rect.bottom - window_rect.top
            local window_aspect = window_width / window_height
            local offset_x = 0
            local offset_y = 0
            if window_aspect >= canvas_aspect then
                offset_x = (window_width - window_height * canvas_aspect) / 2
            else
                offset_y = (window_height - window_width / canvas_aspect) / 2
            end

            mouse_pos.x = canvas_width * (mouse_pos.x - offset_x) / (window_width - offset_x*2)
            mouse_pos.y = canvas_height * (mouse_pos.y - offset_y) / (window_height - offset_y*2)
            
            if (mouse_pos.x >= 0 and mouse_pos.x < canvas_width and mouse_pos.y >= 0 and mouse_pos.y < canvas_height)
                or (data.mouse_pos.x >= 0 and data.mouse_pos.x < canvas_width and data.mouse_pos.y >= 0 and data.mouse_pos.y < canvas_height)
                then
                effect = obs.obs_get_base_effect(obs.OBS_EFFECT_DEFAULT)
                if not effect then
                    return
                end

                obs.obs_enter_graphics()

                local prev_render_target = obs.gs_get_render_target()
                local prev_zstencil_target = obs.gs_get_zstencil_target()

                obs.gs_set_render_target(data.texture, nil)
                obs.gs_viewport_push()
                obs.gs_set_viewport(0, 0, canvas_width, canvas_height)
                obs.gs_projection_push()
                obs.gs_ortho(0, canvas_width, 0, canvas_height, 0.0, 1.0)

                obs.gs_blend_state_push()
                obs.gs_reset_blend_state()

                local dx = mouse_pos.x - data.mouse_pos.x
                local dy = mouse_pos.y - data.mouse_pos.y
                local len = math.sqrt(dx*dx + dy*dy)
                local angle = math.atan2(dy, dx)
                obs.gs_matrix_push()
                obs.gs_matrix_identity()
                obs.gs_matrix_translate3f(data.mouse_pos.x, data.mouse_pos.y, 0)

                obs.gs_matrix_push()
                obs.gs_matrix_translate3f(-data.cap.cx/2, -data.cap.cy/2, 0)
                while obs.gs_effect_loop(effect, "Draw") do
                    obs.obs_source_draw(data.cap.texture, 0, 0, data.cap.cx, data.cap.cy, false);
                end
                obs.gs_matrix_pop()

                obs.gs_matrix_rotaa4f(0, 0, 1, angle)
                obs.gs_matrix_translate3f(0, -data.cap.cy/2, 0)
                obs.gs_matrix_scale3f(len / data.line.cx, 1.0, 1.0)

                while obs.gs_effect_loop(effect, "Draw") do
                    obs.obs_source_draw(data.line.texture, 0, 0, data.line.cx, data.line.cy, false);
                end

                obs.gs_matrix_identity()
                obs.gs_matrix_translate3f(mouse_pos.x, mouse_pos.y, 0)
                obs.gs_matrix_translate3f(-data.cap.cx/2, -data.cap.cy/2, 0)
                while obs.gs_effect_loop(effect, "Draw") do
                    obs.obs_source_draw(data.cap.texture, 0, 0, data.cap.cx, data.cap.cy, false);
                end

                obs.gs_matrix_pop()

                obs.gs_projection_pop()
                obs.gs_viewport_pop()
                obs.gs_blend_state_pop()
                obs.gs_set_render_target(prev_render_target, prev_zstencil_target)

                obs.obs_leave_graphics()

                blank = false
                
            end

            data.mouse_pos = mouse_pos
        end
    else
        data.mouse_pos = nil
    end
end

function clear(pressed)
    if not pressed then
        return
    end

    needs_clear = true
end

function image_source_load(image, file)
    obs.obs_enter_graphics()
    obs.gs_image_file_free(image);
    obs.obs_leave_graphics()

    obs.gs_image_file_init(image, file);

    obs.obs_enter_graphics()
    obs.gs_image_file_init_texture(image);
    obs.obs_leave_graphics()

    if not image.loaded then
        print("failed to load texture " .. file);
    end
end

source_def.video_render = function(data, effect)
    effect = obs.obs_get_base_effect(obs.OBS_EFFECT_DEFAULT)

    if effect and not blank and data.texture then
        obs.gs_blend_state_push()
        obs.gs_reset_blend_state()
        obs.gs_matrix_push()
        obs.gs_matrix_identity()

        while obs.gs_effect_loop(effect, "Draw") do
            obs.obs_source_draw(data.texture, 0, 0, 0, 0, false);
        end

        obs.gs_matrix_pop()
        obs.gs_blend_state_pop()
    end
end

source_def.get_width = function(data)
    return 0
end

source_def.get_height = function(data)
    return 0
end

obs.obs_register_source(source_def)

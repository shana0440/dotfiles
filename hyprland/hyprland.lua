local fileManager = "nautilus"
local menu        = "vicinae toggle"
local mainMod     = "SUPER"

local function quickshellIpc(target, call)
    return "quickshell --path ~/.config/quickshell ipc call " .. target .. " " .. call
end

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

local renderXwaylandAtNativeResolution = { force_zero_scaling = true }
hl.config({ xwayland = renderXwaylandAtNativeResolution })

local servicesWithoutGraphicalSessionTarget = "fcitx5-daemon.service awww.service"
hl.on("hyprland.start", function ()
    hl.exec_cmd("vicinae server")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP"
        .. " && systemctl --user restart " .. servicesWithoutGraphicalSessionTarget)
end)

hl.env("XCURSOR_THEME", "Notwaita-Black")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
        session_lock_xray       = true,
    },
})

local clickToFocusScrollUnderCursor = 2
hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = clickToFocusScrollUnderCursor,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

local macShortcutKeycodes = {
    C = 54, V = 55, X = 53, A = 38, Z = 52, F = 41,
    S = 39, O = 32, L = 46, T = 28, W = 25, R = 27,
}
local function sendFullKeyPressOutsideBind(mods, key)
    hl.timer(function()
        hl.dispatch(hl.dsp.send_shortcut({ mods = mods, key = "code:" .. macShortcutKeycodes[key] }))
    end, { timeout = 1, type = "oneshot" })
    return { ok = true }
end
for _, key in ipairs({ "C", "V", "X", "A", "Z", "F", "S", "O", "L", "T", "W", "R" }) do
    hl.bind(mainMod .. " + " .. key, function()
        return sendFullKeyPressOutsideBind("CTRL", key)
    end, { auto_consuming = true })
end
for _, key in ipairs({ "Z", "T", "R" }) do
    hl.bind(mainMod .. " + SHIFT + " .. key, function() return sendFullKeyPressOutsideBind("CTRL SHIFT", key) end)
end

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(quickshellIpc("capture", "open")))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd(quickshellIpc("lock", "lock")))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(quickshellIpc("wallpaper", "toggle")))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd(quickshellIpc("phone", "toggle")))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", function()
    local window = hl.get_active_window()
    local pid = window and tonumber(window.pid)
    if pid and pid > 1 then
        hl.exec_cmd("kill -TERM " .. math.floor(pid))
    end
end)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))

local layoutBeforeFullscreen = {}
hl.bind("ALT + F", function()
    local window = hl.get_active_window()
    if not window then
        return
    end

    local saved = layoutBeforeFullscreen[window.address]
    if saved or window.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ action = "unset", window = window }))
        if saved then
            hl.dispatch(hl.dsp.window.float({ action = saved.floating and "set" or "unset", window = window }))
            layoutBeforeFullscreen[window.address] = nil
        end
        return
    end

    layoutBeforeFullscreen[window.address] = { floating = window.floating }
    hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
    hl.dispatch(hl.dsp.window.fullscreen({ action = "set", window = window }))
end)

local placementBeforeCentering = {}
local function returnToTiledLayout(window)
    hl.dispatch(hl.dsp.window.float({ action = "unset", window = window }))
end
hl.bind("ALT + SHIFT + F", function()
    local window = hl.get_active_window()
    if not window or window.fullscreen ~= 0 then
        return
    end

    local saved = placementBeforeCentering[window.address]
    if saved then
        placementBeforeCentering[window.address] = nil
        if window.floating then
            hl.dispatch(hl.dsp.window.resize({ x = saved.size.x, y = saved.size.y, window = window }))
            hl.dispatch(hl.dsp.window.move({ x = saved.at.x, y = saved.at.y, window = window }))
            if not saved.floating then
                returnToTiledLayout(window)
            end
        end
        return
    end

    placementBeforeCentering[window.address] = { at = window.at, size = window.size, floating = window.floating }
    local size = window.size
    hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
    hl.dispatch(hl.dsp.window.resize({ x = size.x, y = size.y, window = window }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
end)
hl.on("window.close", function(event)
    if event.window then
        placementBeforeCentering[event.window.address] = nil
        layoutBeforeFullscreen[event.window.address] = nil
    end
end)

local superTap = { held = false, combined = false }
hl.bind("Super_L", function()
    superTap.held = true
    superTap.combined = false
end, { non_consuming = true })
hl.bind(mainMod .. " + Super_L", function()
    if superTap.held and not superTap.combined then
        hl.exec_cmd(quickshellIpc("dashboard", "toggle"))
    end
    superTap.held = false
end, { release = true, non_consuming = true })

local keysAndButtonsThatCombineWithSuper = {
    "Return", "Tab", "space", "Escape", "BackSpace", "Delete", "Insert", "Home", "End",
    "Prior", "Next", "Left", "Right", "Up", "Down", "Print", "minus", "equal",
    "bracketleft", "bracketright", "backslash", "semicolon", "apostrophe", "grave",
    "comma", "period", "slash", "mouse:272", "mouse:273", "mouse:274", "mouse:275",
    "mouse:276", "mouse_up", "mouse_down", "mouse_left", "mouse_right",
}
for c in ("abcdefghijklmnopqrstuvwxyz0123456789"):gmatch(".") do
    table.insert(keysAndButtonsThatCombineWithSuper, c)
end
for i = 1, 12 do
    table.insert(keysAndButtonsThatCombineWithSuper, "F" .. i)
end
for _, key in ipairs(keysAndButtonsThatCombineWithSuper) do
    hl.bind(key, function()
        if superTap.held then
            superTap.combined = true
        end
    end, { non_consuming = true, ignore_mods = true })
end

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for workspace = 1, 10 do
    local digitKey = workspace % 10
    hl.bind("ALT + " .. digitKey, hl.dsp.focus({ workspace = workspace }))
    hl.bind("ALT + SHIFT + " .. digitKey, hl.dsp.window.move({ workspace = workspace }))
end

local function focusAdjacentWorkspaceWithoutWrapping(direction)
    local current = hl.get_active_workspace()
    if not current then
        return
    end
    local target
    local distance = math.huge
    for _, workspace in ipairs(hl.get_workspaces()) do
        local offset = (workspace.id - current.id) * direction
        if workspace.id > 0 and offset > 0 and offset < distance then
            target = workspace.id
            distance = offset
        end
    end
    if target then
        hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
end
hl.bind("CTRL + left", function() focusAdjacentWorkspaceWithoutWrapping(-1) end)
hl.bind("CTRL + right", function() focusAdjacentWorkspaceWithoutWrapping(1) end)
hl.bind("CTRL + up", hl.dsp.exec_cmd(quickshellIpc("overview", "toggle")))

for key, inputMethod in ipairs({ "keyboard-us", "mozc", "chewing" }) do
    hl.bind("CTRL + F" .. key, hl.dsp.exec_cmd("fcitx5-remote -s " .. inputMethod
        .. " && " .. quickshellIpc("inputMethod", "selected " .. inputMethod)))
end

hl.bind(mainMod .. " + CTRL + SPACE", hl.dsp.exec_cmd("hypr-toggle-kana"))

hl.bind(mainMod .. " + ALT + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "float-windscribe",
    match = { class = "^(Windscribe2?|windscribe)$" },

    float  = true,
    center = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

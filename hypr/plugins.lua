-- Hush: optional Hyprland plugins (GloView overview, dynamic-cursors). Safe when they are missing.
-- Install them with `hush plugins install`; install.sh links this file to ~/.config/hush/plugins.lua.
-- Load it from hyprland.lua:
--   pcall(dofile, (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hush/plugins.lua")
local home = os.getenv("HOME") or ""
local user = os.getenv("USER") or ""
local cache = os.getenv("XDG_CACHE_HOME") or (home .. "/.cache")
local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")

local function exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function load_plugin(name)
    if not (hl.plugin and hl.plugin.load) then return false end
    local so = name .. "/" .. name .. ".so"
    for _, dir in ipairs({ "/var/cache/hyprpm/" .. user .. "/", cache .. "/hyprpm/" }) do
        if exists(dir .. so) then
            return pcall(hl.plugin.load, dir .. so)
        end
    end
    return false
end

local have_cursors = load_plugin("dynamic-cursors")
local have_gloview = load_plugin("gloview")

if have_cursors then
    pcall(hl.config, {
        plugin = {
            dynamic_cursors = {
                enabled = true,
                mode = "none",
                shake = {
                    enabled = true,
                    threshold = 8.0,
                    effects = false,
                    base = 2.0, -- magnification
                    nearest = true,
                },
            },
        },
    })
end

if have_gloview then
    local ok, colors = pcall(dofile, config .. "/hypr/modules/gloview-colors.lua")
    if ok and type(colors) == "table" then
        pcall(hl.config, { plugin = { gloview = colors } })
    end
end

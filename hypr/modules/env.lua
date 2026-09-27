hl.env("QT_QPA_PLATFORMTHEME", "qt5ct:qt6ct")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("XCURSOR_THEME", "WhiteSur-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.env("DOTNET_CLI_HOME", _G.env.HOME .. "/.local/share/dotnet")

local dotnet_tools = _G.env.HOME .. "/.local/share/dotnet/tools"
local local_tools = _G.env.HOME .. "/.local/bin"

if not string.find(_G.env.PATH, dotnet_tools, 1, true) then
    hl.env("PATH", _G.env.PATH .. ":" .. dotnet_tools)
end
if not string.find(_G.env.PATH, local_tools, 1, true) then
    hl.env("PATH", _G.env.PATH .. ":" .. local_tools)
end

hl.env("NUGET_PACKAGES", _G.env.HOME .. "/.local/share/nuget/packages")
hl.env("NUGET_HTTP_CACHE_PATH", _G.env.HOME .. "/.cache/nuget/http-cache")
hl.env("NUGET_PLUGINS_CACHE_PATH", _G.env.HOME .. "/.cache/nuget/plugins-cache")

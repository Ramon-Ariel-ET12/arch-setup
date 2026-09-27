local Hy = _G.Hy

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")

    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpm reload -n")
    -- Clipboard history daemon (cclip) — handles text + images via wlr_data_control.
    -- -s 2   ignore single-byte entries (kills nvim unnamedplus "x" noise)
    -- -t     MIME accept order: prefer PNG, then any image, then UTF-8 text, then *.
    hl.exec_cmd("cclipd -s 2 -t image/png -t 'image/*' -t 'text/plain;charset=utf-8' -t 'text/*' -t '*'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd(Hy.terminal)
    hl.exec_cmd("brave-origin")
    hl.exec_cmd("ags run")
end)

-- Permissions
-- hl.permission({ binary = "/usr/(bin|local/bin)/grim",           type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm",        type = "plugin",    mode = "allow" })

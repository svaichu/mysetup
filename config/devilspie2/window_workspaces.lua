-- Pins apps to fixed workspaces on open. devilspie2's set_window_workspace()
-- counts from 1, matching XFCE's UI workspace labels directly.
-- Restored to ~/.config/devilspie2/ by scripts/apply-settings.sh.

if (get_window_class() == "Code") then
    set_window_workspace(1)
end

if (get_window_class() == "Xfce4-terminal") then
    set_window_workspace(2)
end

if (get_window_class() == "firefox") then
    set_window_workspace(5)
end

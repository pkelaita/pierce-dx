-- Rex configuration
-- Docs: https://www.superlogical.com/rex/docs/customize/config
-- Apply changes with: rex config reload

-- Cmd+Left/Right switch tabs. Binding a key replaces its default
-- (sending the key to the terminal), so no unbind is needed.
rex.bind("cmd+right", "client.tab.next")
rex.bind("cmd+left", "client.tab.previous")

-- Cmd+Shift+T applies the Pierce-Special-1 colors to the focused pane.
-- Copied from ~/.config/ghostty/themes/Pierce-Special-1. Rex can't set a
-- theme from init.lua, and set_theme has no selection colors, so those
-- are left out.
local pierce_special_1 = {
  background = "#010A0A",
  foreground = "#48CFCA",
  cursor     = "#F2F4F8",
  scheme     = "dark",
  palette = {
    "0=#282828", "1=#ee5396", "2=#25be6a", "3=#08bdba",
    "4=#78a9ff", "5=#be95ff", "6=#33b1ff", "7=#dfdfe0",
    "8=#484848", "9=#f16da6", "10=#46c880", "11=#2dc7c4",
    "12=#8cb6ff", "13=#c8a5ff", "14=#52bdff", "15=#e4e4e5",
    "16=#3ddbd9",
  },
}

rex.bind("cmd+shift+t", function()
  rex.block.call("com.superlogical.terminal", "set_theme", pierce_special_1)
end)

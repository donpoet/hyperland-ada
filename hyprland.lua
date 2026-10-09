local home = os.getenv("HOME")

package.path =
    home .. "/Projects/hyperland-ada/?.lua;" ..
    home .. "/Projects/hyperland-ada/?/init.lua;" ..
    package.path

require("config.monitor")
require("config.input")
require("config.appearance")
require("config.programs")

require("keybinds.core")
require("keybinds.navigation")
require("keybinds.applications")

require("layouts.ada_layout")

print("Ada Hyprland Lua config loaded")

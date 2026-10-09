-- Switch focus

hl.bind("SUPER + left", hl.dsp.focus({ direction = "left"}))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right"}))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up"}))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down"}))

-- Split view

hl.bind("SUPER + CTRL + left", function()
    hl.dispatch(hl.dsp.layout("l")) 
    hl.dispatch(hl.dsp.exec_cmd("$HOME/.local/bin/fuzzel"))
end)
hl.bind("SUPER + CTRL + right", function()
    hl.dispatch(hl.dsp.layout("r")) 
    hl.dispatch(hl.dsp.exec_cmd("$HOME/.local/bin/fuzzel"))
end)
hl.bind("SUPER + CTRL + up", function()
    hl.dispatch(hl.dsp.layout("u")) 
    hl.dispatch(hl.dsp.exec_cmd("$HOME/.local/bin/fuzzel"))
end)
hl.bind("SUPER + CTRL + down", function()
    hl.dispatch(hl.dsp.layout("d")) 
    hl.dispatch(hl.dsp.exec_cmd("$HOME/.local/bin/fuzzel"))
end)

-- Make float
hl.bind("SUPER + SHIFT + F", function()
    local window = hl.get_active_window()
    
    if not window then
        return
    end

    hl.dispatch(
        hl.dsp.window.float({
            action = "toggle",
            window = window,
        })
    )

    hl.dispatch(
        hl.dsp.layout("ada:refresh")
    )
end)

-- Toggle column width
hl.bind("SUPER + f", hl.dsp.layout("span"))

-- Move windows inside a column
hl.bind("SUPER + SHIFT + right", function()
    hl.dispatch(hl.dsp.layout("mover"))  
end)
hl.bind("SUPER + SHIFT + left", function()
    hl.dispatch(hl.dsp.layout("movel"))  
end)
hl.bind("SUPER + SHIFT + up", function()
    hl.dispatch(hl.dsp.layout("moveu"))  
end)
hl.bind("SUPER + SHIFT + down", function()
    hl.dispatch(hl.dsp.layout("moved"))  
end)

-- Move column on tape
hl.bind("SUPER + ALT + left", function()
    hl.dispatch(hl.dsp.layout("columnleft"))
end)
hl.bind("SUPER + ALT + right", function()
    hl.dispatch(hl.dsp.layout("columnright"))
end)
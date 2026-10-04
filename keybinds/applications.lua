hl.bind("SUPER + space", hl.dsp.exec_cmd("fuzzel"))


local float_next_window = false
local previous_window = nil
hl.on("window.open", function(window)
    if not float_next_window then
        return
    end
    
    float_next_window = false
    
    if window == nil then
        return
    end
    
    hl.dispatch(
        hl.dsp.window.float({
            action = "set",
            window = window
        })
    )

    -- gewünschte Floating-Größe
    hl.dispatch(
        hl.dsp.window.resize({
            window = window,
            x = 1200,
            y = 800,
            relative = false,
        })
    )

    if previous_window and previous_window ~= window then
        hl.dispatch(
            hl.dsp.focus({
                window = previous_window,
            })
        )

        hl.dispatch(
            hl.dsp.focus({
                window = window,
            })
        )
    end

    previous_window = nil
end)
hl.bind("SUPER + SHIFT + space", function()
    float_next_window = true
    previous_window = hl.get_active_window()
    hl.dispatch(hl.dsp.exec_cmd("fuzzel"))
end)

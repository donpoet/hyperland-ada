hl.config({
    general = {
        layout = "lua:ada",

        gaps_in = 8,
        gaps_out = 16,
        border_size = 2,

        col = {
            active_border = {
                colors = {
                    "rgba(c45d12ff)",
                    "rgba(ff2bd6ff)",
                    "rgba(7b2cffff)",
                },
                angle = 45,
            },
            inactive_border = "rgba(30303aff)",
        },
    },

    decoration = {
        rounding = 12,
        active_opacity = 0.90,
        inactive_opacity = 0.80,

        shadow = {
            enabled = true,
            range = 15,
            render_power = 4,
            color = {
                colors = {
                    "rgba(c45d12ff)",
                    "rgba(ff2bd6ff)",
                    "rgba(7b2cffff)",
                },
                angle = 45,
            }
        },
        
        blur = {
            enabled = true,
            size = 6,
            passes = 1,
        },
    },
})
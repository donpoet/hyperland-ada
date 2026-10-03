local state = {
    columns = {},
    order = {},
    active_column = nil,
    pending_split = nil,
}

local function target_id(target)
    local window = target.window
    
    if window then
        return tostring(window.stable_id)
    end

    return tostring(target.index)
end

local function sync_targets(ctx)
    local targets = {}

    for _, target in ipairs(ctx.targets) do 
        targets[target_id(target)] = target
    end

    return targets
end

local function index_of(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end

    return nil
end

local function sync_order(ctx)
    local targets = sync_targets(ctx)
    local new_order = {}

    -- Bestehende Fenster behalten ihre Position
    for _, id in ipairs(state.order) do
        if targets[id] then
            table.insert(new_order, id)
        end
    end

    -- Neue Fenster hinten anhängen
    for id, _ in pairs(targets) do 
        if index_of(new_order, id) == nil then
            table.insert(new_order, id)
        end
    end

    state.order = new_order

    return targets
end

local function create_column()
    return {
        span = 1,
        root = nil
    }
end

local function create_leaf(target)
    return {
        type = "leaf",
        target = target,
    }
end

local function create_split(direction, first, second)
    return {
        type = "split",
        direction = direction,
        children = {
            first,
            second,
        },
    }
end

local function split_leaf(leaf, direction, new_target)
    local old_target = leaf.target

    leaf.type = "split"
    leaf.direction = direction
    leaf.target = nil
    leaf.children = {
        create_leaf(old_target),
        create_leaf(new_target),
    }
end

local function prepare_split(column_index, direction)
    state.pending_split = {
        column = column_index,
        direction = direction,
    }
end

local function split_column(column, direction, new_target)
    if column.root == nil then
        column.root = create_leaf(new_target)
        return
    end

    local old_root = column.root

    column.root = create_split(
        direction,
        old_root,
        create_leaf(new_target)
    )
end

hl.layout.register("ada", {
    recalculate = function(ctx)
        local targets = sync_order(ctx)
        local n = #ctx.targets

        if n == 0 then
            return
        end

        -- Initiale columns anlegen
        while #state.columns < n do
            table.insert(state.columns, create_column())
        end

        -- Jedes Fenster bekommt zunächst eine eigene Column
        for i, target in ipairs(ctx.targets) do
            local column = state.columns[i]

            if column.root == nil then
                column.root = create_leaf(target)
            else
                column.root.target = target
            end

            target:place(ctx:column(i, n))
        end

        state.active_column = 1

    end,
})
local COLUMN_WIDTH = 1700

local state = {
    columns = {},
    pending_split = nil,
    tape_offset = 0,
}

local function target_id(target)
    local window = target.window
    
    if window then
        return tostring(window.stable_id)
    end

    return tostring(target.index)
end

local function active_id(ctx)
    local active = hl.get_active_window()

    if not active then
        return nil
    end

    local active_id = tostring(active.stable_id)

    for _, target in ipairs(ctx.targets) do
        local window = target.window

        if window and tostring(window.stable_id) == active_id then
            return active_id
        end
    end

    return nil
end

local function create_column()
    return {
        span = 1,
        root = nil
    }
end

local function create_leaf(id)
    if id == nil then
        error("ada: create_leaf received nil id")
    end

    return {
        type = "leaf",
        id = id,
    }
end

local function create_split(direction, first, second)
    return {
        type = "split",
        direction = direction,
        ratio = 0.5,
        children = {
            first,
            second,
        },
    }
end

local function find_column(node, id, column)
    if not node then
        return nil
    end

    if node.type == "leaf" then
        if node.id == id then
            return column
        end

        return nil
    end

    return find_column(node.children[1], id, column)
        or find_column(node.children[2], id, column)
end

local function find_column_for_id(id)
    if not id then
        return nil
    end

    for _, column in ipairs(state.columns) do
        if find_column(column.root, id, column) then
            return column
        end
    end

    return nil
end

local function find_column_index(id)
    if not id then
        return nil
    end

    for index, column in ipairs(state.columns) do
        if find_column(column.root, id, column) then
            return index
        end
    end

    return nil
end

local function insert_split(node, id, direction, new_id)
    if not node then
        return nil, false
    end

    if node.type == "leaf" then
        if node.id ~= id then
            return node, false
        end

        return create_split(
            direction,
            create_leaf(id),
            create_leaf(new_id)
        ), true
    end

    local child, changed = insert_split(
        node.children[1],
        id,
        direction,
        new_id
    )

    if changed then
        node.children[1] = child
        return node, true
    end

    child, changed = insert_split(
        node.children[2],
        id,
        direction,
        new_id
    )

    if changed then
        node.children[2] = child
        return node, true
    end

    return node, false
end

local function remove_id(node, id)
    if not node then
        return nil, false
    end

    if node.type == "leaf" then
        if node.id == id then
            return nil, true
        end

        return node, false
    end

    local child, changed = remove_id(node.children[1], id)

    if changed then
        node.children[1] = child
    else
        child, changed = remove_id(node.children[2], id)

        if changed then
            node.children[2] = child
        end
    end

    if not changed then
        return node, false
    end

    if not node.children[1] then
        return node.children[2], true
    end

    if not node.children[2] then
        return node.children[1], true
    end

    return node, true
end

local function collect_ids(node, result)
    if not node then
        return
    end

    if node.type == "leaf" then
        result[node.id] = true
        return
    end

    collect_ids(node.children[1], result)
    collect_ids(node.children[2], result)
end

local function remove_missing_targets(present)
    for _, column in ipairs(state.columns) do
        local ids = {}
        collect_ids(column.root, ids)

        for id in pairs(ids) do
            if not present[id] then
                local root, changed = remove_id(column.root, id)

                if changed then 
                    column.root = root
                end
            end
        end
    end

    local remaining = {}

    for _, column in ipairs(state.columns) do
        if column.root then
            table.insert(remaining, column)
        end
    end

    state.columns = remaining

end

local function place_node(ctx, targets, node, area)
    if not node then
        return
    end

    if node.type == "leaf" then
        local target = targets[node.id]

        if target then
            target:place(area)
        end

        return
    end

    local ratio = node.ratio or 0.5
    
    local first_area
    local second_area

    if node.direction == "d" then
        first_area = ctx:split(area, "up", ratio)
        second_area = ctx:split(area, "down", ratio)
    elseif node.direction == "r" then
        first_area = ctx:split(area, "left", ratio)
        second_area = ctx:split(area, "right", ratio)
    elseif node.direction == "u" then
        first_area = ctx:split(area, "down", ratio)
        second_area = ctx:split(area, "up", ratio)
    elseif node.direction == "l" then
        first_area = ctx:split(area, "right", ratio)
        second_area = ctx:split(area, "left", ratio)
    end

    place_node(ctx, targets, node.children[1], first_area)
    place_node(ctx, targets, node.children[2], second_area)
end

local function get_column_area(ctx, index, tape_offset)
    local x = ctx.area.x + tape_offset

    for i = 1, index -1 do
        x = x + state.columns[i].span * COLUMN_WIDTH
    end

    local column = state.columns[index]

    return {
        x = x,
        y = ctx.area.y,
        w = column.span * COLUMN_WIDTH,
        h = ctx.area.h,
    }
end

local function collect_geometry(ctx, targets, node, area, result)
    if not node then
        return
    end

    table.insert(result, {
        node = node,
        area = area,
    })

    if node.type == "leaf" then
        return
    end

    local ratio = node.ratio or 0.5
    
    local first_area
    local second_area

    if node.direction == "d" then
        first_area = ctx:split(area, "up", ratio)
        second_area = ctx:split(area, "down", ratio)
    
    elseif node.direction == "r" then
        first_area = ctx:split(area, "left", ratio)
        second_area = ctx:split(area, "right", ratio)
    
    elseif node.direction == "u" then
        first_area = ctx:split(area, "down", ratio)
        second_area = ctx:split(area, "up", ratio)
    
    elseif node.direction == "l" then
        first_area = ctx:split(area, "right", ratio)
        second_area = ctx:split(area, "left", ratio)
    end

    collect_geometry(ctx, targets, node.children[1], first_area, result)
    collect_geometry(ctx, targets, node.children[2], second_area, result)
end

local function area_contains(outer, inner)
    return
        inner.x >= outer.x
        and inner.y >= outer.y
        and inner.x + inner.w <= outer.x + outer.w
        and inner.y + inner.h <= outer.y + outer.h
end

local function find_boundry_match(geometry, source_area, direction)
    local source_left = source_area.x
    local soure_right = source_area.x + source_area.w
    local source_top = source_area.y
    local source_bottom = source_area.y + source_area.h

    local best = nil
    local best_difference = nil

    for _, entry in ipairs(geometry) do
        local area = entry.area

        local left = area.x
        local right = area.x + area.w
        local top = area.y
        local bottom = area.y + area.h

        local matches = false
        local difference = nil

        if direction == "right" then
            if left == soure_right and top == source_top and bottom == source_bottom then
                matches = true
                difference = math.abs(area.w - source_area.w)
            end
        elseif direction == "left" then
            if right == source_left and top == source_top and bottom == source_bottom then
                matches = true
                difference = math.abs(area.w - source_area.w)
            end
        elseif direction == "down" then
            if top == source_bottom and left == source_left and right == soure_right then
                matches = true
                difference = math.abs(area.h - source_area.h)
            end
        elseif direction == "up" then
            if bottom == source_top and left == source_left and right == soure_right then
                matches = true
                difference = math.abs(area.h - source_area.h)
            end
        end

        if matches then
            if not best_difference or difference < best_difference then
                best = entry.node
                best_difference = difference
            end
        end
    end
    
    return best
end

local function swap_nodes(first, second)
    if not first or not second or first == second then
        return
    end

    local first_type = first.type
    local first_id = first.id
    local first_direction = first.direction
    local first_ratio = first.ratio
    local first_children = first.children

    first.type = second.type
    first.id = second.id
    first.direction = second.direction
    first.ratio = second.ratio
    first.children = second.children

    second.type = first_type
    second.id = first_id
    second.direction = first_direction
    second.ratio = first_ratio
    second.children = first_children
end

local function move_window(ctx, direction)
    local active = active_id(ctx)

    if not active then
        return false
    end

    local column = find_column_for_id(active)

    if not column then
        return false
    end

    local column_index = find_column_index(active)

    if not column_index then
        return false
    end

    local targets = {}

    for _, target in ipairs(ctx.targets) do
        local window = target.window

        if window and not window.floating then
            targets[target_id(target)] = target
        end
    end

    local geometry = {}

    local column_area = get_column_area(
        ctx,
        column_index,
        state.tape_offset
    )
    
    collect_geometry(
        ctx,
        targets,
        column.root,
        column_area,
        geometry
    )

    local source_area = nil
    
    for _, entry in ipairs(geometry) do
        if entry.node.type == "leaf" and entry.node.id == active then
            source_area = entry.area
            break
        end
    end

    if not source_area then
        return false
    end

    local source = nil
    local destination = nil
    local best_source_area = nil
    for _, entry in ipairs(geometry) do
        if area_contains(entry.area, source_area) then
            local candidate = find_boundry_match(
                geometry,
                entry.area,
                direction
            )

            if candidate then
                local candidate_size = entry.area.w * entry.area.h

                if not best_source_area or candidate_size < best_source_area then
                    source = entry
                    destination = candidate
                    best_source_area = candidate_size
                end
            end
        end
    end

    if not source or not destination then
        return false
    end

    swap_nodes(source.node, destination)

    return true
end

local function add_new_target(id)
    local pending = state.pending_split

    if pending then
        local column = find_column_for_id(pending.id)

        if column then
            local root, changed = insert_split(
                column.root,
                pending.id,
                pending.direction,
                id
            )

            if changed then
                column.root = root
                state.pending_split = nil
                return
            end
        end

        state.pending_split = nil
    end

    local column = create_column()
    column.root = create_leaf(id)
    table.insert(state.columns, column)
end

local function calculate_tape_offset(ctx, active_column)
    local viewport_width = ctx.area.w
    local tape_width = 0

    for _, column in ipairs(state.columns) do 
        tape_width = tape_width + column.span * COLUMN_WIDTH
    end

    if tape_width <= viewport_width then
        return 0
    end

    local offset = state.tape_offset

    if active_column then


        local column_left = ctx.area.x + offset
        for i = 1, active_column -1 do
            column_left = column_left + state.columns[i].span * COLUMN_WIDTH
        end

        local column_right = column_left + state.columns[active_column].span * COLUMN_WIDTH

        local viewport_left = ctx.area.x
        local viewport_right = ctx.area.x + viewport_width

        -- Aktive Column ist links außerhalb
        if column_left < viewport_left then
            offset = offset + (viewport_left - column_left)
        end

        -- Aktive Column ist rechts außerhalb
        if column_right > viewport_right then
            offset = offset - (column_right - viewport_right)
        end
    end

    -- Tape darf nicht über den linken Rand hinaus laufen
    if offset > 0 then
        offset = 0
    end

    -- Tape darf nicht über den rechten Rand hinaus laufen
    local minimum_offset = viewport_width - tape_width

    if offset < minimum_offset then
        offset = minimum_offset
    end

    return offset
end

local function recalculate(ctx)

    local targets = {}
    local present = {}

    for _, target in ipairs(ctx.targets) do
        local window = target.window

        if window and not window.floating then
            local id = target_id(target)
                
            targets[id] = target
            present[id] = true
        end
    end

    remove_missing_targets(present)

    local remaining_columns = {}

    for _, column in ipairs(state.columns) do
        local ids = {}

        collect_ids(column.root, ids)

        local has_window = false

        for id in pairs(ids) do
            if present[id] then
                has_window = true
                break
            end
        end

        if has_window then
            table.insert(remaining_columns, column)
        end
    end

    state.columns = remaining_columns

    local known = {}

    for _, column in ipairs(state.columns) do
        collect_ids(column.root, known)
    end

    for _, target in ipairs(ctx.targets) do
        local window = target.window

        if window and not window.floating then

            local id = target_id(target)

            if not known[id] then
                add_new_target(id)
                known[id] = true
            end
        end
    end

    local active = active_id(ctx)
    local active_column = find_column_index(active)
    local tape_offset = calculate_tape_offset(ctx, active_column)
    state.tape_offset = tape_offset

    if #state.columns == 0 then
        return
    end

    for index, column in ipairs(state.columns) do
        local area = get_column_area(ctx, index, tape_offset)
        place_node(ctx, targets, column.root, area)
    end
end

local function move_column(ctx, direction)
    local active = active_id(ctx)

    if not active then
        return
    end

    local index = find_column_index(active)

    if not index then
        return
    end

    local target = index

    if direction == "left" then
        target = index - 1
    elseif direction == "right" then
        target = index + 1
    end

    if target < 1 or target > #state.columns then
        return
    end

    state.columns[index], state.columns[target] = 
        state.columns[target], state.columns[index]
end

hl.layout.register("ada", {recalculate=recalculate,
    layout_msg = function(ctx, msg)

        if msg == "ada:refresh" then
            recalculate(ctx)
            return true
        end

        local command = msg:match("^(%S+)")
        local id = active_id(ctx)

        if command == "span" then
            if id then
                local column = find_column_for_id(id)

                if column then
                    if column.span == 1 then
                        column.span = 2
                    else
                        column.span = 1
                    end
                end
            end

            recalculate(ctx)
            return true
        end

        if command == "columnleft" then
            move_column(ctx, "left")
            recalculate(ctx)
            return true
        end

        if command == "columnright" then
            move_column(ctx, "right")
            recalculate(ctx)
            return true
        end

        if command == "mover" then
            move_window(ctx, "right")
            recalculate(ctx)
            return true
        end

        if command == "movel" then
            move_window(ctx, "left")
            recalculate(ctx)
            return true
        end

        if command == "moveu" then
            move_window(ctx, "up")
            recalculate(ctx)
            return true
        end

        if command == "moved" then
            move_window(ctx, "down")
            recalculate(ctx)
            return true
        end

        if command == "splitu" or command == "u" then
            if id then
                state.pending_split = {
                    id = id,
                    direction = "u",
                }
            end

            return true
        end

        if command == "splitd" or command == "d" then
            if id then
                state.pending_split = {
                    id = id,
                    direction = "d",
                }
            end

            return true
        end

        if command == "splitl" or command == "l" then
            if id then
                state.pending_split = {
                    id = id,
                    direction = "l",
                }
            end

            return true
        end

        if command == "splitr" or command == "r" then
            if id then
                state.pending_split = {
                    id = id,
                    direction = "r",
                }
            end

            return true
        end

        return "ada: expected splitu, splitd, splitl or splitr"
    end,
})

hl.on("window.active", function()
    hl.dispatch(hl.dsp.layout("ada:refresh"))
end)
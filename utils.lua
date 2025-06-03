local utils = {}

function utils.distance(x1, y1, x2, y2)
    return ((x2 - x1)^2 + (y2 - y1)^2)^0.5
end

function utils.deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.deepCopy(orig_key)] = utils.deepCopy(orig_value)
        end
        setmetatable(copy, utils.deepCopy(getmetatable(orig)))
    else -- number, string, boolean, function etc.
        copy = orig
    end
    return copy
end

return utils

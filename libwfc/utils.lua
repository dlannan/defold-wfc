
function newArray( n, init )

    local array = {}
    for i=0, n-1 do array[i] = init end 
    return array 
end 

function makeColor( r, g, b )

    local color = 0xff000000
    local shB = bit.lshift(b, 16)
    local shG = bit.lshift(g, 8)

    color = bit.bor(color, r )
    color = bit.bor(color, shG)
    color = bit.bor(color, shB)
    return color
end

function tableMatch( p1, p2 )

    for i=0, table.count(p1) do if p1[i] ~= p2[i] then return false end end
    return true 
end

function ToPower(a, n)
    local product = 1
    for i = 0, n-1 do product = product * a end
    return product
end

function GetPixel( bitmap, x, y )

    -- local idx = x * 4 + y * bitmap.Width * 4
    -- return 
    -- { 
    --     r = string.byte(bitmap.data, idx + 1), 
    --     g = string.byte(bitmap.data, idx + 2), 
    --     b = string.byte(bitmap.data, idx + 3) 
    -- }

    local r,g,b,a = libwfc.image_getpixel( bitmap.id, x, y )
    return { r = r, g = g, b = b }
end

function Random(weights, r)

    local sum = 0
    for i = 0, table.count(weights)-1 do sum = sum + weights[i] end 
    local threshold = r * sum

    local partialSum = 0
    for i = 0, table.count(weights)-1 do
        partialSum = partialSum + weights[i]
        if (partialSum >= threshold) then return i end 
    end
    return 0
end

string.split = function(self, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

table.count = function(tbl)
    local count = 0
    for k,v in pairs(tbl) do
        count = count + 1
    end 
    return count 
end

require("libwfc.xmlsimple")
local xdocument = newParser()
local model = require("libwfc.model")

local tiledmodel = {
    tiles               = {},
    tilenames           = {},
    tilesize            = 0,
    blackBackground     = false,
}

SimpleTiledModel = {}

SimpleTiledModel.new = function( name, subsetName, width, height, periodic, blackBackground, heuristic )

    local tmodel = model_new( width, height, 1, periodic, heuristic )
    tmodel.blackBackground = blackBackground
    tmodel.type     = "SimpleTiledModel"
    pprint(name)
    
    tmodel.tiles               = {}
    tmodel.tilenames           = {}
    tmodel.tilesize            = 0
    tmodel.blackBackground     = false

    local xroot = xdocument:loadFile( "samples/"..name.."/data.xml"):children()[1]
    local sprops = xroot:properties()
    tmodel.tilesize = tonumber(sprops["size"] or 16) 
    local unique = string.lower(sprops["unique"] or "false") == "true"

    local subset = nil
    if(subsetName) then 

        local xsubset = {}
        xmlElementFilter( xroot, "subsets", function( ss )
            xmlElementFilter( ss.element, "subset", function( sss )
                pprint(sss.props["name"])
                if( sss.props["name"] == subsetName ) then
                    xmlElementFilter( sss.element, "tile", function(etile) 
                        xsubset[etile.props["name"]] = etile.element
                    end)
                end
            end)
        end)

        if( table.count(xsubset) == 0 ) then 
            print("ERROR: subset "..subsetName.." is not found") 
        else 
            subset = xsubset 
        end 
    end
    
    local function tile( func )
        local result = newArray( tmodel.tilesize * tmodel.tilesize, {r=0, g=0, b=0} )
        for y=0, tmodel.tilesize-1 do 
            for x =0, tmodel.tilesize-1 do 
                result[ x + y * tmodel.tilesize] = func(x,y) 
            end 
        end 
        return result 
    end

    local function rotate( array ) 
        return tile( function(x,y) return array[ tmodel.tilesize - 1 - y + x * tmodel.tilesize ] end )
    end
    local function reflect( array ) 
        return tile( function(x,y) return array[ tmodel.tilesize - 1 - x + y * tmodel.tilesize ] end )
    end

    tmodel.tiles = {} 
    tmodel.tilenames = {} 
    local weightList = {}

    local action = {}
    local firstOccurrence = {}

    xmlElementFilter( xroot, "tiles", function( tiles )
        xmlElementFilter( tiles.element, "tile", function( etile )

            local tilename = etile.props["name"]
            local filetest = (subset and subset[tilename] == nil)
            if( not filetest ) then  
                local a,b = nil, nil
                local cardinality = 0 
                
                local sym = etile.props["symmetry"] or 'X'
                if( sym == 'L' ) then 
                    cardinality = 4
                    a = function( i ) return (i + 1) % 4 end 
                    b = function( i ) if( i % 2 == 0 ) then return i + 1 else return i - 1 end end
                elseif( sym == 'T' ) then 
                    cardinality = 4
                    a = function( i ) return (i + 1) % 4 end 
                    b = function( i ) if( i % 2 == 0 ) then return i else return 4 - i end end
                elseif(sym == 'I' ) then 
                    cardinality = 2
                    a = function( i ) return 1 - i end 
                    b = function( i ) return i end
                elseif(sym == '\\') then 
                    cardinality = 2
                    a = function( i ) return 1 - i end 
                    b = function( i ) return 1 - i end
                elseif(sym == 'F') then 
                    cardinality = 8
                    a = function( i ) if( i < 4 ) then return (i + 1) % 4 else return 4 + (i - 1) % 4 end end 
                    b = function( i ) if( i < 4 ) then return i + 4 else return i - 4 end end
                else 
                    cardinality = 1
                    a = function( i ) return i end 
                    b = function( i ) return i end
                end 

                tmodel.T = table.count(action)
                firstOccurrence[tilename] = tmodel.T

                local map = newArray( cardinality, {} )
                for t = 0, cardinality - 1 do 

                    map[t] = {}
                    map[t][0] = t 
                    map[t][1] = a(t)
                    map[t][2] = a(a(t))
                    map[t][3] = a(a(a(t)))
                    map[t][4] = b(t)
                    map[t][5] = b(a(t))
                    map[t][6] = b(a(a(t)))
                    map[t][7] = b(a(a(a(t))))

                    for s = 0, 7 do map[t][s] = map[t][s] + tmodel.T end 
                    table.insert(action, map[t])
                end 

                if(unique == true) then 

                    for t = 0, cardinality - 1 do 
                        -- pprint("samples/" .. name.."/"..tilename.." "..t..".png")
                        local bitmapId    = libwfc.image_load("samples/" .. name.."/"..tilename.." "..t..".png")
                        local w, h, comp, data = libwfc.image_get(bitmapId)
                        local bitmap     = { id=bitmapId, Width = w, Height = h, Comp = comp, data = data }
                        
                        local tdata  = tile( function(x,y) return GetPixel(bitmap, x, y) end )
                        table.insert(tmodel.tiles, tdata)
                        table.insert(tmodel.tilenames, tilename.." "..t) 
                    end 
                else 
                    local bitmapId    = libwfc.image_load( "samples/" .. name.."/"..tilename..".png" )
                    local w, h, comp, data = libwfc.image_get(bitmapId)
                    local bitmap     = { id=bitmapId, Width = w, Height = h, Comp = comp, data = data }
                    
                    local tdata = tile( function(x,y) return GetPixel(bitmap, x, y) end )
                    table.insert(tmodel.tiles, tdata)
                    table.insert(tmodel.tilenames, tilename.." 0")

                    for t = 1, cardinality - 1 do 
                        if( t <= 3 ) then 
                            local rotdata =  rotate( tmodel.tiles[tmodel.T + t] )
                            table.insert(tmodel.tiles, rotdata) 
                        end 
                        if( t >= 4 ) then 
                            local refdata =  reflect( tmodel.tiles[tmodel.T + t - 3] )
                            table.insert(tmodel.tiles, refdata) 
                        end 
                        table.insert(tmodel.tilenames, tilename.." "..t)
                    end
                end

                for t = 0, cardinality-1 do 
                    local last = table.count(weightList)
                    weightList[last] = tonumber(etile.props["weight"]) or 1.0 
                end 
            end
        end)
    end)

    assert(table.count(action) > 0, "No actions? :"..table.count(action))
    tmodel.T = table.count(action)
    tmodel.weights = weightList

    tmodel.propagator = newArray(4, {})
    local densePropagator = newArray(4, {}) 

    for d = 0, 3 do 
        densePropagator[d] = newArray(tmodel.T, {})
        tmodel.propagator[d] = newArray(tmodel.T, {}) 
        for t = 0, tmodel.T-1 do 
            densePropagator[d][t] = {} 
        end 
    end

    xmlElementFilter( xroot, "neighbors", function( nbrs )
        xmlElementFilter( nbrs.element, "neighbor", function( nbr )
            local left = nbr.props["left"]:split( " " )
            local right = nbr.props["right"]:split( " " )

            local test = (subset and (( subset[left[1]] == nil ) or ( subset[right[1]] == nil ))) 

            if not test then
                local llen = tonumber(left[2] or 0)
                local L = action[firstOccurrence[left[1]]+1][llen]
                local D = action[L+1][1]
                local rlen = tonumber(right[2] or 0)
                local R = action[firstOccurrence[right[1]]+1][rlen]
                local U = action[R+1][1]

                densePropagator[0][R][L] = true
                densePropagator[0][action[R+1][6]][action[L+1][6]] = true
                densePropagator[0][action[L+1][4]][action[R+1][4]] = true
                densePropagator[0][action[L+1][2]][action[R+1][2]] = true

                densePropagator[1][U][D] = true
                densePropagator[1][action[D+1][6]][action[U+1][6]] = true
                densePropagator[1][action[U+1][4]][action[D+1][4]] = true
                densePropagator[1][action[D+1][2]][action[U+1][2]] = true
            end
        end) 
    end)

    for t2 = 0, tmodel.T-1 do 
        for t1 = 0, tmodel.T-1 do
            densePropagator[2][t2][t1] = densePropagator[0][t1][t2]
            densePropagator[3][t2][t1] = densePropagator[1][t1][t2]
        end
    end

    local sparsePropagator = newArray( 4, {} )
    for d = 0, 3 do
        sparsePropagator[d] = newArray( tmodel.T, {} )
        for t = 0, tmodel.T-1 do 
            sparsePropagator[d][t] = {}
        end 
    end 
    
    for d = 0, 3 do 
        for t1 = 0, tmodel.T-1 do
            local sp = sparsePropagator[d][t1]
            local tp = densePropagator[d][t1]

            for t2 = 0, tmodel.T-1 do 
                if (tp[t2] == true) then 
                    local tc = table.count(sp)
                    sp[tc] = t2 
                end
            end

            local ST = table.count(sp)
            if(ST == 0) then 
                pprint("ERROR: tile "..tmodel.tilenames[t1 + 1].." has no neighbors in direction "..d)
            end
            tmodel.propagator[d][t1] = {}
            for sst = 0, ST-1 do 
                tmodel.propagator[d][t1][sst] = sp[sst] 
            end
        end
    end 

    tmodel.GraphicsSave = function( self, filename )
        local bdata, w, h = SimpleTiledModel.Graphics(self) 
        --Write out data to filename 
        local count = libwfc.image_save( filename, w, h, bdata)
        assert(count == w * h, "[ IMAGE ERROR ] "..count.."  "..(w*h))
    end

    tmodel.TextOutput = function(self)

        local result = ""
        for  y = 0, self.MY-1 do 
            for x = 0, self.MX-1 do
                result = result..tostring( self.tilenames[self.observed[x + y * self.MX] + 1] )
            end
            result = result.."\n"
        end
        return result
    end

    return tmodel
end

local function CountTrues( arr )
    local count = 0
    if(arr and table.count(arr) > 0) then 
        for i,v in pairs( arr ) do
            if(v == true) then count = count + 1 end 
        end
    end
    return count
end

local function GetLambdas( T, arr, weights)
    local sum = 0
    if( arr and table.count(arr) > 0 ) then
    for i = 0, T-1 do 
        if(arr[i] == true) then 
            sum = sum + weights[i]
        end 
    end 
    end
    return sum
end

SimpleTiledModel.Graphics = function(tmodel)
    
    local bitmapData = {}
    if (tmodel.observed[0] >= 0) then
        for x = 0, tmodel.MX-1 do 
            for y = 0, tmodel.MY-1 do
                local tile = tmodel.tiles[ tmodel.observed[x + y * tmodel.MX]+1]
                for yt = 0, tmodel.tilesize-1 do 
                    for xt = 0, tmodel.tilesize-1 do
                        local c = tile[xt + yt * tmodel.tilesize]
                        bitmapData[x * tmodel.tilesize + xt + (y * tmodel.tilesize + yt) * tmodel.MX * tmodel.tilesize] =
                            makeColor(c.r, c.g, c.b)
                    end
                end
            end
        end 
    else
        for x = 0, tmodel.MX-1 do 
            for y = 0, tmodel.MY-1 do

                local a = tmodel.wave[x + y * tmodel.MX]
                local amount = CountTrues(a)
                local lambda = 1.0 / GetLambdas(tmodel.T, a, tmodel.weights)

                for yt = 0, tmodel.tilesize-1 do 
                    for xt = 0, tmodel.tilesize-1 do
                        if (tmodel.blackBackground and amount == tmodel.T) then
                            bitmapData[x * tmodel.tilesize + xt + (y * tmodel.tilesize + yt) * tmodel.MX * tmodel.tilesize] = 0xff000000
                        else
                            local r, g, b = 0, 0, 0
                            for t = 0, tmodel.T-1 do 
                                if (a[t]) then
                                    local c = tmodel.tiles[t+1][xt + yt * tmodel.tilesize]
                                    r = r + c.r * tmodel.weights[t] * lambda;
                                    g = g + c.g * tmodel.weights[t] * lambda;
                                    b = b + c.b * tmodel.weights[t] * lambda;
                                end
                            end

                            bitmapData[x * tmodel.tilesize + xt + (y * tmodel.tilesize + yt) * tmodel.MX * tmodel.tilesize] = 
                                makeColor(r,g,b)
                        end
                    end
                end
            end
        end
    end
    return bitmapData, tmodel.MX * tmodel.tilesize, tmodel.MY * tmodel.tilesize
end



return SimpleTiledModel
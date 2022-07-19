
require("libwfc.xmlsimple")
local xdocument = newParser()
local model = require("libwfc.model")

local tiledmodel = {
    patterns            = {},
    colors              = {},
}

OverlappingModel = {}

OverlappingModel.new = function( name, N, width, height, periodicInput, periodic, symmetry, ground, heuristic )

    local tmodel = model_new( width, height, N, periodic, heuristic )

    tmodel.type     = "OverlappingModel"
    tmodel.ground   = ground 

    pprint(name)

    local png_path  = 'samples/'..name
    if(OverlappingModel.png_path) then png_path = OverlappingModel.png_path end
    
    local bitmapId  = libwfc.image_load(png_path..'.png')
    if(bitmapId == nil) then print("[ERROR] Cannot load: "..png_path..'.png'); return nil end
    local w, h, comp, data = libwfc.image_get(bitmapId)
    local bitmap    = { id=bitmapId, Width = w, Height = h, Comp = comp, data = data }
    local SX        = bitmap.Width
    local SY        = bitmap.Height
    local sample    = newArray( SX * SY,  0)
    tmodel.colors   = {}
    
    for y = 0, SY-1 do 
        for x = 0, SX - 1 do 
            local color = GetPixel(bitmap, x, y)

            local i = 0
            for k,c in pairs(tmodel.colors) do 
                if( (c.r == color.r) and (c.b == color.b) and (c.g == color.g) ) then break end 
                i = i + 1
            end

            if( i == table.count(tmodel.colors) ) then 
                tmodel.colors[i] = color 
            end
            sample[x + y * SX] = i;
        end 
    end

    local C = table.count(tmodel.colors)
    local W = ToPower( C, tmodel.N * tmodel.N )

    local function pattern( func )
        local result = newArray( tmodel.N * tmodel.N, 0 )
        for y=0, tmodel.N-1 do
            for x = 0, tmodel.N-1 do 
                result[x + y * tmodel.N] = func(x,y)
            end 
        end
        return result
    end

    local function patternFromSample( bx, by ) 
        return pattern( function( tx, ty ) return sample[ ((bx+tx) % SX) + ((by + ty) % SY) * SX ] end )
    end
    local function rotate( p ) 
        return pattern( function(x,y) return p[tmodel.N - 1 - y + x * tmodel.N] end) 
    end
    local function reflect( p ) 
        return pattern( function(x,y) return p[tmodel.N - 1 - x + y * tmodel.N] end) 
    end

    local function index( p )
        local result = 0
        local power = 1 
        local pcount = table.count(p)
        for i = 0, pcount - 1 do 
            result = result + p[pcount - 1 - i] * power 
            power = power * C 
        end
        return result
    end

    local function patternFromIndex( ind )
        local residue = ind 
        local power =  W 
        local result = newArray( tmodel.N * tmodel.N, 0 )
        for i=0, tmodel.N * tmodel.N-1 do 
            power = power / C 
            local count = 0 
            while( residue >= power) do 
                residue = residue - power 
                count = count + 1
            end
            result[i] = count   
        end
        return result
    end

    local Tweights = {} 
    local ordering = {} 
    local ycount = SY - tmodel.N + 1
    if(periodicInput == true) then ycount = SY end 
    local xcount = SX - tmodel.N + 1
    if(periodicInput == true) then xcount = SX end 
    for y = 0, ycount - 1 do 
        local test = 1
        for x = 0, xcount - 1 do

            local ps = newArray( 8, {} )
            ps[0]   = patternFromSample(x, y)
            ps[1]   = reflect(ps[0])
            ps[2]   = rotate(ps[0])
            ps[3]   = reflect(ps[2])
            ps[4]   = rotate(ps[2])
            ps[5]   = reflect(ps[4])
            ps[6]   = rotate(ps[4])
            ps[7]   = reflect(ps[6])

            for k = 0, symmetry-1 do 
                local ind = index(ps[k])
                if(Tweights[ind]) then 
                    Tweights[ind] = Tweights[ind] + 1
                else 
                    Tweights[ind] = 1
                    local last = table.count(ordering)
                    ordering[last] = ind
                end 
            end 
        end
    end 

    tmodel.T = table.count(Tweights)
    tmodel.ground = ground 
    tmodel.patterns = newArray( tmodel.T, {} )
    tmodel.weights = newArray( tmodel.T, 0.0 ) 

    local counter = 0
    for i = 0, table.count(ordering)-1 do
        local w = ordering[i] 
        tmodel.patterns[counter] = patternFromIndex(w) 
        tmodel.weights[counter] = Tweights[w]
        counter = counter + 1
    end

    function agrees( p1, p2, dx, dy )

        local xmin = dx
        if(dx < 0) then xmin = 0 end 
        local xmax = tmodel.N
        if(dx < 0) then xmax = dx + tmodel.N end
        local ymin = dy 
        if(dy < 0) then ymin = 0 end
        local ymax = tmodel.N
        if(dy < 0) then ymax = dy + tmodel.N end
        for y = ymin, ymax-1 do 
            for x = xmin, xmax - 1 do 
                if ( p1[x + tmodel.N * y] ~= p2[x - dx + tmodel.N * (y - dy)] ) then 
                    return false 
                end
            end 
        end 
        return true
    end

    tmodel.propagator = newArray(4, {})
    for d = 0, 3 do 
        tmodel.propagator[d] = newArray( tmodel.T, {} )
        for t = 0, tmodel.T-1 do 
            local list = {} 
            for t2 = 0, tmodel.T-1 do 
                if( agrees( tmodel.patterns[t], tmodel.patterns[t2], tmodel.Gdx[d+1], tmodel.Gdy[d+1]) == true ) then 
                    local last = table.count(list)
                    list[last] = t2 
                end
            end
            tmodel.propagator[d][t] = {} 
            for c = 0, table.count(list)-1 do 
                tmodel.propagator[d][t][c] = list[c] 
            end 
        end 
    end 

    tmodel.GraphicsSave = function( self, filename )
        local bdata, w, h = OverlappingModel.Graphics(self) 
        --Write out data to filename 
        local count = libwfc.image_save( filename, w, h, bdata)
        table.insert(self.genfiles, filename)
        assert(count == w * h, "[ IMAGE ERROR ] "..count.."  "..(w*h))
    end

    return tmodel
end

-- Draw the data to a png bitmap
OverlappingModel.Graphics = function( tmodel )

    local bitmapData = {}

    if (tmodel.observed[0] >= 0) then 
        for y = 0, tmodel.MY-1 do 
        
            local dy = tmodel.N - 1
            if y < tmodel.MY - tmodel.N + 1 then dy = 0 end 
            for x = 0, tmodel.MX-1 do
                local dx = tmodel.N - 1
                if x < tmodel.MX -tmodel.N + 1 then dx = 0 end 
                local c = tmodel.colors[tmodel.patterns[tmodel.observed[x - dx + (y - dy) *tmodel.MX]][dx + dy *tmodel.N]]
                bitmapData[x + y * tmodel.MX] = makeColor( c.r, c.g, c.b )
            end
        end
    else
    
        for i = 0, table.count(tmodel.wave) - 1 do
            local contributors, r, g, b = 0, 0, 0, 0
            local x = i % tmodel.MX
            local y = math.floor( (i / tmodel.MX) )

            for dy = 0, tmodel.N-1 do 
                for dx = 0, tmodel.N-1 do
                    local sx = x - dx
                    if (sx < 0) then sx = sx + tmodel.MX end

                    local sy = y - dy
                    if (sy < 0) then sy = sy + tmodel.MY end

                    local s = sx + sy * tmodel.MX
                    if (tmodel.periodic == false and ((sx + tmodel.N > tmodel.MX) or (sy + tmodel.N > tmodel.MY) or (sx < 0) or (sy < 0)) ) then 
                        
                    else
                        for t = 0, tmodel.T -1 do
                            if (tmodel.wave[s][t] == true) then                        
                                contributors = contributors + 1;
                                local color = tmodel.colors[ tmodel.patterns[t][dx + dy * tmodel.N]]
                                r = r + color.r
                                g = g + color.g
                                b = b + color.b
                            end
                        end
                    end
                end
            end
            bitmapData[i] = makeColor( math.floor(r/contributors), math.floor(g/contributors), math.floor(b/contributors) )
        end
    end

    return bitmapData, tmodel.MX, tmodel.MY, 4
end

return OverlappingModel
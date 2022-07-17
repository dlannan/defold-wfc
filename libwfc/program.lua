
require("libwfc.utils")
require("libwfc.xmlsimple")
local xdocument  = newParser()

local SimpleTiledModel  = require("libwfc.simpletiledmodel")
local OverlappingModel  = require("libwfc.overlappingmodel")

local program = {}

local function dumpProps( e )

    for k,v in pairs(e.properties) do
        print( "[ "..tostring(k) .. " ]  "..tostring(v) )
    end
end


-- Run the model to generate the waveform collapse
local function runModel( model, e )

    local screenshots = tonumber(e.props["screenshots"]) or 2
    print("Screenshots: "..screenshots)
    for i = 0, screenshots-1 do
        for k = 0, 9 do
            io.write("> ");io.flush()
            local seed      = math.floor(os.clock() * 1000000)
            local limit     = tonumber(e.props["limit"]) or -1
            local success   = model:run(seed, limit)

            if (success) then 
                io.write("DONE\n")
                io.flush()
                model:GraphicsSave("output/"..e.props["name"] .. " " .. seed .. ".png")
                if (model.type == "SimpleTiledModel" ) then 
                    if( e.props["textOutput"] == "True" ) then  
                        print( model:TextOutput() )
                    end 
                end
                break
            else 
                io.write("CONTRADICTION\n")
                io.flush()
            end
        end
    end
end 

-- Check the properties of an element
program.checkProps = function( e, overlapping )

    local dim = 24
    if(overlapping) then dim = 48 end

    local size  = tonumber(e.props[ "size" ] or dim) 
    local width = tonumber(e.props[ "width" ] or size) 
    local height = tonumber(e.props[ "height" ] or size)
    local periodic = (string.lower(e.props[ "periodic" ] or "false") == "true")
    local heuristicString  = e.props[ "heuristic" ]

    local heuristic = Heuristic.entropy
    if(heuristicString == "Scanline") then 
        heuristic = Heuristic.scanline 
    elseif( heuristicString == "MRV") then
        heuristic = Heuristic.mrv 
    end 

    local model = nil
    if( overlapping ) then 
        local N = tonumber(e.props["N"] or 3)  
        local periodicInput = (string.lower(e.props["periodicInput"] or "true") == "true") 
        local symmetry = tonumber(e.props["symmetry"] or 8) 
        local ground = string.lower(e.props["ground"] or "false") == "true"
        model = OverlappingModel.new( e.props["name"], N, 512, 512, periodicInput, periodic, symmetry, ground, heuristic )
    else 
        local subset = e.props["subset"]
        local blackBackground = (string.lower(e.props["blackBackground"] or "false") == "true") 
        model = SimpleTiledModel.new( e.props["name"], subset, width, height, periodic, blackBackground, heuristic )
    end

    if(model) then runModel(model,  e) end
end

program.main = function()

    -- program.sw = timer.delay( 0.2, true, function() 
    --     -- Timer update
    -- end)
    program.runQ = {}
    local info = sys.get_sys_info()
    -- The system OS name: "Darwin", "Linux", "Windows", "HTML5", "Android" or "iPhone OS"
    if info.system_name == "Linux" or info.system_name == "Darwin" then
        os.execute( "rm -f output/*.png")
    end 

    if info.system_name == "Windows" then
        os.execute( "del output\\*.png")
    end

    local xdoc = xdocument:loadFile( "main/samples.xml" )
    for k,v in pairs( xdoc:children() ) do
        print(k,v:name())

        local overlapping = xmlElementFilter( v, "overlapping", function(e)
            table.insert( program.runQ, { e=e, overlap=true } )
        end)

        local simpletiled = xmlElementFilter( v, "simpletiled" , function(e)

            table.insert( program.runQ, { e=e, overlap=false } )
        end)
    end
end

return program
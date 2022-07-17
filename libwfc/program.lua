
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
program.checkProps = function( gui, e, overlapping )

    local dim = 24
    if(overlapping) then dim = 48 end

    local name              = gui.model_name
    local size              = gui.model_size
    local width             = gui.model_width
    local height            = gui.model_height
    local periodic          = gui.model_periodic
    local heuristic         = gui.model_heuristic

    local model = nil
    if( overlapping ) then 
        local N = gui.model_N
        local periodicInput = gui.model_periodicInput
        local symmetry = gui.model_symmetry
        local ground = gui.model_ground
        model = OverlappingModel.new( name, N, width, height, periodicInput, periodic, symmetry, ground, heuristic )
    else 
        local subset = gui.model_subset
        local blackBackground = gui.model_blackBackground
        model = SimpleTiledModel.new( name, subset, width, height, periodic, blackBackground, heuristic )
    end

    if(model) then 
        runModel(model,  e)
        for k,v in pairs( model.genfiles ) do
            local newid = libwfc.image_loadsize( v, 512, 512 )
            table.insert( gui.totalfiles, { filename = v, id = newid } )
        end 
    end
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

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local model = {

    Gdx = { -1, 0, 1, 0 },
    Gdy = { 0, 1, 0, -1 },
    Gopposite = { 2, 3, 0, 1 },    

    wave            = {},
    propagator      = {},
    compatible      = {},
    observed        = {},
    stack           = {},

    stacksize       = 0,
    observedSoFar   = 0,
    
    MX              = 0,
    MY              = 0,
    T               = 0,
    N               = 0,

    periodic        = 0,
    ground          = 0,

    weights         = {},
    weightLogWeights= {},
    distribution    = {},

    sumsOfOnes      = {},
    sumOfWeights    = {},
    sumOfWeightLogWeights = {},
    startingEntropy = {},

    sumsOfWeights   = {},
    sumsOfWeightLogWeights = {},
    entropies       = {},
}

Heuristic = {
    entropy     = 1,
    mrv         = 2,
    scanline    = 3,
}

model.heuristic     = Heuristic.entropy

model.init = function( self )

    self.wave = newArray( self.MX * self.MY, {} )
    self.compatible = newArray( self.MX * self.MY, {} ) 

    for i = 0, self.MX * self.MY - 1 do 
        self.wave[i] = newArray(self.T, false)
        self.compatible[i] = {}
        for t = 0, self.T - 1 do 
            self.compatible[i][t] = newArray(4, 0) 
        end
    end
    self.distribution = newArray( self.T, 0.0 )
    self.observed = newArray( self.MX * self.MY, 0 )

    self.weightLogWeights =  newArray( self.T, 0 )
    self.sumOfWeights = 0
    self.sumOfWeightLogWeights = 0 

    for t = 0, self.T-1 do
        self.weightLogWeights[t] = self.weights[t+1] * math.log(self.weights[t+1])
        self.sumOfWeights = self.sumOfWeights + self.weights[t+1] 
        self.sumOfWeightLogWeights = self.sumOfWeightLogWeights + self.weightLogWeights[t]
    end 

    self.startingEntropy = math.log( self.sumOfWeights ) - self.sumOfWeightLogWeights / self.sumOfWeights

    self.sumsOfOnes = newArray( self.MX * self.MY, 0 )
    self.sumsOfWeights = newArray( self.MX * self.MY, 0 ) 
    self.sumsOfWeightLogWeights = newArray( self.MX * self.MY, 0 )
    self.entropies = newArray( self.MX * self.MY, 0 )

    self.stack = newArray( self.MX * self.MY * self.T, {} )
    self.stacksize = 0
end

model.run = function( self, seed, limit )

    if(table.count(self.wave) == 0) then self:init() end 
    self:clear()
    math.randomseed(seed)

    local rand = os.clock()

    local l = 0
    while( (l < limit) or( limit < 0) ) do

        local node = self:nextunobservednode( )
        if( node >= 0 ) then 
            self:observe( node )
            local success = self:propagate()
            if(not success) then return false end 
        else 
            for i=0, table.count(self.wave) -1 do
                for t = 0, self.T-1 do 
                    if( self.wave[i][t] == true ) then 
                        self.observed[i] = t 
                        break 
                    end 
                end 
            end 
            return true
        end 
        l=l+1
    end 
    return true
end

model.nextunobservednode = function( self )

    if( self.heuristic == Heuristic.scanline ) then 
        for i = self.observedSoFar, table.count(self.wave) - 1 do 
            if( self.periodic == false and (( (i % self.MX) + self.N > self.MX ) or ( math.floor(i / self.MX) + self.N > self.MY )) ) then 
            else
                if( self.sumsOfOnes[i] > 1 ) then
                    self.observedSoFar = i + 1
                    return i 
                end
            end
        end
        return -1
    end

    local min = 1e+4
    local argmin = -1

    for i=0, table.count(self.wave) -1 do 
        if( self.periodic == false and (( (i % self.MX) + self.N > self.MX ) or ( math.floor(i / self.MX) + self.N > self.MY))) then 
        else 
            local remainingValues = self.sumsOfOnes[i]
            local entropy = remainingValues
            if( self.heuristic == Heuristic.entropy ) then entropy = self.entropies[i] end

            if((remainingValues > 1) and (entropy <= min)) then 
                local noise = 1e-6 * math.random()
                if(entropy + noise < min) then 

                    min = entropy + noise
                    argmin = i 
                end 
            end 
        end
    end 

    return argmin
end 

model.observe = function( self, node )

    local w = self.wave[node]
    for t = 0, self.T-1 do 
        self.distribution[t] = 0.0 
        if( w[t] == true ) then self.distribution[t] = self.weights[t+1] end
    end 
    local r = Random( self.distribution, math.random() )
    print(r)
    for t=0, self.T-1 do 
        if( w[t] ~= ( t == r )) then 
            self:ban( node, t ) 
        end 
    end
end

model.propagate = function( self )

    while( self.stacksize > 0 ) do

        local s = self.stack[self.stacksize - 1]
        local i1, t1 = s[1], s[2]
        self.stacksize = self.stacksize - 1

        local x1 = i1 % self.MX
        local y1 = math.floor( (i1 / self.MX) ) 

        for d=0, 3 do 

            local x2 = x1 + self.Gdx[d+1]
            local y2 = y1 + self.Gdy[d+1]

            if( self.periodic == false and ((x2 < 0) or (y2 < 0) or (x2 + self.N > self.MX) or (y2 + self.N > self.MY) )) then 

            else
                if(x2 < 0) then x2 = x2 + self.MX 
                elseif( x2 >= self.MX ) then x2 = x2 - self.MX end
                if(y2 < 0) then y2 = y2 + self.MY 
                elseif( y2 >= self.MY ) then y2 = y2 - self.MY end 

                local i2 = x2 + y2 * self.MX 
                local p = self.propagator[d][t1]
                local compat = self.compatible[i2]
                for l, v in pairs(p) do
                    local comp = compat[v]
                    comp[d] = comp[d] - 1 
                    if(comp[d] == 0 ) then self:ban( i2, v ) end 
                end
            end
        end
    end
    return (self.sumsOfOnes[0] > 0)
end

model.ban = function ( self, i, t )

    self.wave[i][t] = false 

    local comp = self.compatible[i][t]
    for d = 0, 3 do comp[d] = 0 end 
    self.stack[self.stacksize] = { i, t }
    self.stacksize = self.stacksize + 1

    self.sumsOfOnes[i] = self.sumsOfOnes[i] - 1 
    self.sumsOfWeights[i] = self.sumsOfWeights[i] - self.weights[t+1] 
    self.sumsOfWeightLogWeights[i] = self.sumsOfWeightLogWeights[i] - self.weightLogWeights[t] 

    local sum = self.sumsOfWeights[i]
    self.entropies[i] = math.log(sum) - self.sumsOfWeightLogWeights[i] / sum 
end 

model.clear = function( self )

    for i=0, table.count(self.wave) -1 do 
        for t = 0, self.T -1 do 
            self.wave[i][t] = true 
            for d = 0, 3 do 
                self.compatible[i][t][d] = table.count(self.propagator[self.Gopposite[d+1]][t])
            end 
        end 

        self.sumsOfOnes[i] = table.count(self.weights)
        self.sumsOfWeights[i] = self.sumOfWeights
        self.sumsOfWeightLogWeights[i] = self.sumOfWeightLogWeights
        self.entropies[i] = self.startingEntropy
        self.observed[i] = -1
    end

    self.observedSoFar = 0 
    if( self.ground == true ) then 
        for x=0, self.MX-1 do 
            for t = 0, self.T - 2 do self:ban( x + (self.MY - 1) * self.MX , t ) end 
            for y = 0, self.MY - 2 do self:ban( x + y * self.MX, self.T - 1) end 
        end 
        self:propagate()
    end 
end 

model_new = function( width, height, N, periodic, heuristic )

    local mdl = deepcopy(model)
    mdl.MX = width 
    mdl.MY = height 
    mdl.N  = N
    mdl.periodic = periodic 
    mdl.heuristic = heuristic
    return mdl 
end

return model
--[[
    GD50
    Breakout Remake

    -- Powerup Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents a "Powerup" which starts falling from the screen, and when hit
    by the player's paddle, will spawn additional balls.
]]
Powerup = Class{}

local POWERUP_SPEED = 30
local ROTATION_SPEED = 0.35

local POWERUPS = {
    REMOVE_BALLS = 1,
    SPLIT_BALLS = 2,
    ADD_LIFE = 3,
    TAKE_LIFE = 4,
    PADDLE_UP = 5,
    PADDLE_DOWN = 6,
    ADD_BALLS = 9,
    UNLOCK_KEY = 10
}

local GOOD_POWERUPS = { 2, 3, 5, 9, 10, 10 }
local BAD_POWERUPS = { 1, 4, 6 }
local NUM_GOOD = table.getn(GOOD_POWERUPS)
local NUM_BAD = table.getn(BAD_POWERUPS)


local paletteColors = {
    -- red X
    [1] = { ['r'] = 217 / 255, ['g'] = 87 / 255, ['b'] = 99 / 255 },
    -- green X
    [2] = { ['r'] = 106 / 255, ['g'] = 190 / 255, ['b'] = 47 / 255 },
    -- red heart
    [3] = { ['r'] = 217 / 255, ['g'] = 87 / 255, ['b'] = 99 / 255 },
    -- red skull
    [4] = { ['r'] = 217 / 255, ['g'] = 87 / 255, ['b'] = 99 / 255 },
    -- gold up
    [5] = { ['r'] = 251 / 255, ['g'] = 242 / 255, ['b'] = 54 / 255 },
    -- gold down
    [6] = { ['r'] = 251 / 255, ['g'] = 242 / 255, ['b'] = 54 / 255 },
    -- blue small ball
    [7] = { ['r'] = 99 / 255, ['g'] = 155 / 255, ['b'] = 255 / 255 },
    -- blue big ball
    [8] = { ['r'] = 99 / 255, ['g'] = 155 / 255, ['b'] = 255 / 255 },
    -- blue plus ball
    [9] = { ['r'] = 99 / 255, ['g'] = 155 / 255, ['b'] = 255 / 255 },
    -- gold key
    [10] = { ['r'] = 251 / 255, ['g'] = 242 / 255, ['b'] = 54 / 255 }
}

function Powerup:init(x, y)
    self.x = x
    self.y = y
    self.width = 16
    self.height = 16
    self.rotation = 0
    self.dy = 0
    self.active = false
    self.skin = 0
    self.particleSystem = nil
end

function Powerup:reset(x, y, options)
    -- reset powerup's position
    self.x = x
    self.y = y
    self.rotation = 0
    self.dy = POWERUP_SPEED
    self.active = true

    -- "good" power ups should spawn more often than "bad" ones
    local needPowerupChoice = true
    local currentlyDroppingPowerup = 0
    while needPowerupChoice do
        -- choose powerup based on simple rules
        if math.random(3) <= 1 then
            currentlyDroppingPowerup = BAD_POWERUPS[math.random(NUM_BAD)]
        else
            currentlyDroppingPowerup = GOOD_POWERUPS[math.random(NUM_GOOD)]
        end

        -- check that we're "happy" with this choice - assume it's OK and
        -- look for exceptions
        needPowerupChoice = false
        if POWERUPS['UNLOCK_KEY'] == currentlyDroppingPowerup and not options['needKey'] then
            needPowerupChoice = true  -- player doesn't need key yet
            
        elseif POWERUPS['REMOVE_BALLS'] == currentlyDroppingPowerup and options['numBalls'] <= 1 then
            needPowerupChoice = true  -- there's only 1 ball in play
        
        elseif POWERUPS['ADD_LIFE'] == currentlyDroppingPowerup and options['health'] >= 3 then
            needPowerupChoice = true  -- player already has max lives
        
        elseif POWERUPS['TAKE_LIFE'] == currentlyDroppingPowerup and options['health'] <= 1 then
            needPowerupChoice = true  -- player down to last life
        
        elseif POWERUPS['PADDLE_UP'] == currentlyDroppingPowerup and options['paddleSize'] >= (options['level'] >= 6 and 2 or 4) then
            needPowerupChoice = true  -- player's paddle already big enough for their skill
        
        elseif POWERUPS['PADDLE_DOWN'] == currentlyDroppingPowerup and options['paddleSize'] <= 1 then
            needPowerupChoice = true  -- player's paddle already at min size
        
        end
    end
    self.skin = currentlyDroppingPowerup

    -- particle system for when powerup hits paddle
    self.particleSystem = love.graphics.newParticleSystem(gTextures['particle'], 64)

    -- lasts between 0.5-1 seconds seconds
    self.particleSystem:setParticleLifetime(0.5, 1.0)

    -- give it an acceleration of anywhere between X1,Y1 and X2,Y2
    -- had these different to the settings in Ball.lua but it didn't look good
    self.particleSystem:setLinearAcceleration(-15, 0, 15, 80)

    -- spread of particles; normal looks more natural than uniform
    self.particleSystem:setEmissionArea('normal', 10, 10)

    -- Fade to from blue to clear
    local n = self.skin
    self.particleSystem:setColors(paletteColors[n].r, paletteColors[n].g, paletteColors[n].b, 0.8,
        paletteColors[n].r, paletteColors[n].g, paletteColors[n].b, 0.0) 
end

--[[
    Expects an argument with a bounding box for the paddle, and returns true if
    the bounding boxes of this and the argument overlap.

    TODO: This code copied from Ball.lua, should probably move AABB test
    to Util.lua
]]
-- Simple AABB Collision
function Powerup:collides(target)
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 
    return true
end

--[[
    Called when the player hits the powerup with their paddle. Currently only
    skips #3 & #9 are supported -- this spawns more balls from the paddle.
]]
function Powerup:hit(playState)
    -- register the hit
    self.active = false
    self.particleSystem:emit(64)

    -- execute the powerup based on skin
    if POWERUPS['ADD_LIFE'] == self.skin then
        -- add new life
        gSounds['recover']:play()
        playState.health = math.min(3, playState.health + 1)

    elseif POWERUPS['TAKE_LIFE'] == self.skin then
        -- takes a life, but doesn't take the last one
        gSounds['hurt']:play()
        playState.health = math.max(1, playState.health - 1)

    elseif POWERUPS['PADDLE_UP'] == self.skin then
        -- paddle gets bigger
        gSounds['powerup']:play()
        playState.paddle:reset(playState.paddle.size + 1)

        -- but also, balls speed up a little
        for k, ball in pairs(playState.balls) do
            ball.dx = ball.dx * 1.3
            ball.dy = ball.dy * 1.3
        end

    elseif POWERUPS['PADDLE_DOWN'] == self.skin then
        -- paddle gets smaller
        gSounds['hurt']:play()
        playState.paddle:shrink()

        -- but also, balls slow down a little
        for k, ball in pairs(playState.balls) do
            ball.dx = ball.dx * 0.7
            ball.dy = ball.dy * 0.7
        end

    elseif POWERUPS['UNLOCK_KEY'] == self.skin then
        -- enables breaking locks
        playState.canBreakLocks = true

    elseif POWERUPS['REMOVE_BALLS'] == self.skin then

        gSounds['hurt']:play()        
        playState.balls = { playState.balls[1] }
        playState.balls[1].dy = math.abs(playState.balls[1].dy) * -1

    elseif POWERUPS['SPLIT_BALLS'] == self.skin then
        -- splits balls
        gSounds['powerup']:play()
        local balls = { }
        local i = 1
        for k, ball in pairs(playState.balls) do
            if ball.active then
                -- copy existing ball
                balls[i] = ball

                instantiatedBall = Ball(ball.skin)
                instantiatedBall.x = ball.x
                instantiatedBall.y = ball.y 
                instantiatedBall.dx = -ball.dx
                instantiatedBall.dy = math.abs(ball.dy) * -1
                balls[i + 1] = instantiatedBall
                i = i + 2
            end
        end
        -- save the new list
        playState.balls = balls 

    elseif POWERUPS['ADD_BALLS'] == self.skin then
        -- 2 new balls, flying off randomly
        gSounds['powerup']:play()
        local balls = { }

        -- first, copy over the ones currently in play
        local i = 1
        for k, ball in pairs(playState.balls) do
            if ball.active then
                balls[i] = ball
                i = i + 1
            end
        end

        -- spawn 2 new balls...but sometimes, go crazy...
        local num_new_balls = math.random(5) == 1 and 12 or 2
        while num_new_balls >= 0 do
            -- ball spawns at players paddle
            ball = Ball()
            ball.skin = math.random(4)
            --middle of the paddle
            ball.x = playState.paddle.x + (playState.paddle.width / 2) - (ball.width / 2)
            ball.y = playState.paddle.y - ball.height

            -- ramdom direction
            ball.dx = math.random(-200, 200)
            ball.dy = math.random(-50, -60)

            balls[i] = ball
            i = i + 1
            num_new_balls = num_new_balls - 1
        end

        -- save the new list
        playState.balls = balls

    else
        -- a powerup we haven't handled! Let's just give points...
        gSounds['powerup']:play()
        playState.score = playState.score + 500
        print(string.format("ERROR: Unhandled powerup number %d", self.skin))
    end
end


function Powerup:update(dt)
    if self.active then
        -- fall and spin
        self.y = self.y + self.dy * dt
        self.rotation = self.rotation + ROTATION_SPEED * (dt * 50)

        -- powerup goes out of play once it drops off screen
        if self.y > VIRTUAL_HEIGHT + self.height then
            self.active = false
        end
    elseif self.particleSystem then
        self.particleSystem:update(dt)
    end
end

function Powerup:render()
    if self.active then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][self.skin],
            self.x, self.y, self.rotation, 1, 1, self.width / 2, self.height / 2)
    elseif self.particleSystem then
        love.graphics.draw(self.particleSystem, self.x, self.y + self.height / 2)
    end
end

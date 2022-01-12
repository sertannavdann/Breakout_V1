--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]
local num_balls = 0
local x = true
PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = params.balls
    self.level = params.level

    self.recoverPoints = 5000 or params.recoverPoints

    -- give ball random starting velocity
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)
    self.powerup = Powerup(VIRTUAL_WIDTH / 2, 0)
    self.powerup.active = false
    
    self.canBreakLocks = false
    self.numLockedBricks = 0
    for k, brick in pairs(self.bricks) do
        if brick.isLocked then
            self.numLockedBricks = self.numLockedBricks + 1
        end
    end
end

function PlayState:update(dt)
    -- Little Hack to showcase keys in the upcoming levels
    if love.keyboard.wasPressed('x') then
        x = not x
    end
    --Little Hack to show the powerups whenever we press z
    if love.keyboard.wasPressed('z') then
        self.powerup:reset(self.paddle.x + self.paddle.width / 2,
        self.paddle.y - self.paddle.height * 3, 
        { 
            needKey = self.numLockedBricks > 0 and not self.canBreakLocks,
            health = self.health,
            paddleSize = self.paddle.size,
            numBalls = #self.balls,
            level = self.level
        })
    end

    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    -- self.ball:update(dt)
    for i, ball in pairs(self.balls) do
        ball:update(dt)
    end
    self.powerup:update(dt)
    if self.powerup.active and self.powerup:collides(self.paddle) then
        self.powerup:hit(self)
    end

    for k, ball in pairs(self.balls) do
        if ball:collides(self.paddle) then
        -- raise ball above paddle in case it goes below it, then reverse dy
        ball.y = self.paddle.y - 8
        ball.dy = -ball.dy

        -- tweak angle of bounce based on where it hits the paddle

        -- if we hit the paddle on its left side while moving left...
        if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
            ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))

        -- else if we hit the paddle on its right side while moving right...
        elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
           ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
        end

        gSounds['paddle-hit']:play()
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do
        for i, ball in pairs(self.balls) do
        -- only check collision if we're in play
        if brick.active and ball:collides(brick) then

            -- add to score
            self.score = self.score + (brick.tier * 200 + brick.color * 25)
            -- trigger the brick's hit function, which removes it from play
            wasLocked = brick.isLocked
            brick:hit(self.canBreakLocks)
            if wasLocked and not brick.isLocked then
                self.numLockedBricks = self.numLockedBricks - 1
                self.canBreakLocks = false 
            end
            if math.random(3) == 2 and not self.powerup.active then
                self.powerup:reset(brick.x + brick.width / 2, brick.y,
                {
                    needKey = self.numLockedBricks > 0 and not self.canBreakLocks,
                    health = self.health,
                    paddleSize = self.paddle.size,
                    numBalls = #self.balls,
                    level = self.level
                }) 
            end

            -- if we have enough points, recover a point of health
            if self.score > self.recoverPoints then
                -- can't go above 3 health
                self.health = math.min(3, self.health + 1)

                -- multiply recover points by 2
                self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

                self.paddle:reset(2)
                -- play recover sound effect
                gSounds['recover']:play()
            end

            -- go to our victory screen if there are no more bricks left
            if self:checkVictory() then
                gSounds['victory']:play()

                gStateMachine:change('victory', {
                    level = self.level,
                    paddle = self.paddle,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    balls = self.balls,
                    recoverPoints = self.recoverPoints
                })
            end

            -- collision code for bricks
            -- we check to see if the opposite side of our velocity is outside of the brick;
            -- if it is, we trigger a collision on that side. else we're within the X + width of
            -- the brick and should check to see if the top or bottom edge is outside of the brick,
            -- colliding on the top or bottom accordingly 

            -- left edge; only check if we're moving right, and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            if ball.x + 2 < brick.x and ball.dx > 0 then

                -- flip x velocity and reset position outside of brick
                ball.dx = -ball.dx
                ball.x = brick.x - 8

            -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then

                -- flip x velocity and reset position outside of brick
                ball.dx = -ball.dx
                ball.x = brick.x + 32

            -- top edge if no X collisions, always check
            elseif ball.y < brick.y then

                -- flip y velocity and reset position outside of brick
                ball.dy = -ball.dy
                ball.y = brick.y - 8

            -- bottom edge if no X collisions or top collision, last possibility
            else
                
                -- flip y velocity and reset position outside of brick
                ball.dy = -ball.dy
                ball.y = brick.y + 16
            end

            -- slightly scale the y velocity to speed up the game, capping at +- 150
            if math.abs(ball.dy) < 150 then
                ball.dy = ball.dy * 1.02
            end

            -- only allow colliding with one brick, for corners
            break
        end
    end

    -- if all the balls* goes below bounds,
    -- revert to serve state and decrease health
    local active_balls = num_balls
    for j, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            gSounds['hurt']:play()
            ball.active = false
            num_balls = num_balls - num_balls
        else
            num_balls = num_balls + 1
        end
    end

    for j, ball in pairs(self.balls) do
        if not ball.active then
            table.remove(self.balls, j)
        end
    end

    -- only lose health if all balls are now out of play
    if num_balls <= 0 then
        self.health = self.health - 1
        gSounds['hurt']:play()

        if self.health == 0 then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            self.paddle:reset(math.min(3, self.paddle.size + 1))
            gStateMachine:change('serve', {
                paddle = self.paddle,
                bricks = self.bricks,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints
            })
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

        if love.keyboard.wasPressed('escape') then
            love.event.quit()
        end
    end
end
    end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end
    self.powerup:render()
    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    -- self.ball:render()
    for k, ball in pairs(self.balls) do
        ball:render()
    end

    renderLevel(self.level)
    renderScore(self.score)
    renderHealth(self.health)
    renderPowerups(self.canBreakLocks)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    if x then
        for k, brick in pairs(self.bricks) do
            if brick.active then
                return false
            end 
        end
    end
    return true
end
local keys = {
    x = 0, 
    y = 0
}

local mario = {
    x = 0,
    y = 0,
    vx = 0,
    vy = 0,
    dir = "right"
}

local sprite = {
    walk = {
        left = {},
        right = {}
    },
    stand = {
        left = {},
        right = {}
    },
    jump = {
        left = {},
        right = {}
    }
}

local coords = {}

local function gravity(dt, mario)
    if mario.y > 0 then
        mario.vy = mario.vy - dt/4
    else
        mario.vy = 0
    end
end

local function jump(keys, mario)
    if keys.y > 0 and mario.vy == 0 then
       mario.vy = 6
    end
end

local function walk(keys, mario)
    mario.vx = keys.x
    if keys.x < 0 then
        mario.dir = "left"
    elseif keys.x > 0 then
        mario.dir = "right"
    end
end

local function physics(dt, mario)
    mario.x = mario.x + dt * mario.vx
    mario.y = math.max(0, mario.y + dt * mario.vy)
end

local currentAnim
local currentIndex = 1
local currentFrameTime = 0

local currentAction

local function display(dt, mario)
    currentFrameTime = currentFrameTime + dt
    if currentFrameTime > 0.1 then
        currentFrameTime = 0
        currentIndex = currentIndex + 1
    end

    if mario.y > 0 then
        currentAction = "jump"
    elseif mario.vx ~= 0 then
        currentAction = "walk"
    else
        currentAction = "stand"
    end

    currentAnim = sprite[currentAction][mario.dir] or sprite.stand.left

    if currentIndex > #currentAnim then
        currentIndex = 1
    end

end


return {
    load = function()
        table.insert(sprite.stand.left,
            love.graphics.newImage("mario/stand/left.gif"))
        table.insert(sprite.stand.right,
            love.graphics.newImage("mario/stand/right.gif"))
        table.insert(sprite.jump.left,
            love.graphics.newImage("mario/jump/left.gif"))
        table.insert(sprite.jump.right,
            love.graphics.newImage("mario/jump/right.gif"))

        for i=1, 8 do
            table.insert(sprite.walk.left,
                love.graphics.newImage("mario/walk/left/"..i..".gif"))
        end

        for i=1, 7 do
            table.insert(sprite.walk.right,
                love.graphics.newImage("mario/walk/right/"..i..".gif"))
        end
        currentAction = "stand"
        currentAnim = sprite.stand.left
        currentIndex = 1
    end,
    update = function(dt)
        keys.x = 0
        keys.y = 0
        dt = dt * 100
        if love.keyboard.isDown("left") then
            keys.x = -1
        end
        if love.keyboard.isDown("right") then
            keys.x = 1
        end
        if love.keyboard.isDown("up") then
            keys.y = 1
        end
        if love.keyboard.isDown("down") then
            keys.y = -1
        end
        gravity(dt, mario)
        jump(keys, mario)
        walk(keys, mario)
        physics(dt, mario)
        display(dt, mario)
        if mario.vx ~= 0 or mario.vy ~= 0 then
            table.insert(coords, {mario.x, mario.y})
        end
    end,
    draw = function()
        love.graphics.setColor(174, 238, 238)
        love.graphics.rectangle("fill", 0, 0, 800, 480)
        love.graphics.setColor(74, 167, 43)
        love.graphics.rectangle("fill", 0, 480, 800, 640)
        love.graphics.setColor(0, 0, 0, 128)
        local prev
        for i, coord in ipairs(coords) do
            if prev then
                love.graphics.line(prev[1] + 15, 450-prev[2] + 10,
                 coord[1] + 15, 450-coord[2] + 10)
            end
            prev = coord
        end
        love.graphics.setColor(255, 255, 255)
        if currentAnim then
            love.graphics.draw(currentAnim[currentIndex], mario.x, 450- mario.y)
        end
        
    end
}


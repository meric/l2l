package.path = package.path ..";../../?.lua"
local debugger = require("l2l.ext.debugger")
local game = require("mario")

local record = debugger.record

-- Declare functions involving side effects.
love.keyboard.isDown = record(love.keyboard.isDown)

love.load = game.load

local is_paused = false
local frames = debugger.context("mario"):watch(game.update)
local rewind_index = 0

love.keypressed = function(key, isrepeat)
    if key == "p" then
        is_paused = not is_paused
        if not is_paused then
            debugger.rewind("mario", frames[steps] or 0)
        end
    end
end

local is_dragging

local function move_slider(x, y)
    local index = math.floor(((x - 620) / (765 - 620)) * steps)
    index = math.min(steps, math.max(0, index))
    rewind_index = index
    debugger.rewind("mario", frames[rewind_index] or 0)
end

love.mousepressed = function(x, y)
    if is_paused then
        if x > 620 and x < 765 and y > 80 and y < 90 then
            is_dragging = true
            move_slider(x, y)
        end
    end
end

love.mousereleased = function(x, y)
    is_dragging = false
end

love.update = function(dt)
    steps = #frames
    if not is_paused then
        game.update(dt)
        rewind_index = steps
    elseif is_dragging then
        move_slider(love.mouse.getX(), love.mouse.getY())
    end
end

love.draw = function()
    game.draw()

    love.graphics.setColor(160, 160, 160)
    love.graphics.rectangle("fill", 600, 0, 800, 640)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Press Left, Right, \nUp to move Mario.", 620, 20)

    if not is_paused then
        love.graphics.print("Press P to Pause.", 620, 60)
    else
        love.graphics.print("Press P to Resume.", 620, 60)
    end
    if is_paused then
        love.graphics.print(0, 610, 80)
        love.graphics.print(steps, 770, 80)
        love.graphics.setColor(255, 255, 255)
        love.graphics.line(620, 85, 765, 85)
        love.graphics.setColor(100, 100, 200)
        local position = (765 - 620) * (rewind_index/steps)
        love.graphics.rectangle("fill", 620+position, 80, 5, 10)
    end
end

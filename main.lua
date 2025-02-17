-- Tetris game in Lua using Löve framework

-- Load necessary libraries
local shapes = {
    { {0, 0}, {1, 0}, {0, 1}, {1, 1} }, -- O shape
    { {0, 0}, {1, 0}, {2, 0}, {1, 1} }, -- T shape
    { {0, 0}, {1, 0}, {0, 1}, {0, 2} }, -- L shape
    { {0, 0}, {1, 0}, {1, 1}, {2, 1} }, -- Z shape
    { {0, 0}, {1, 0}, {2, 0}, {3, 0} }, -- I shape
}

local colors = {
    {1, 0, 0}, -- Red
    {0, 1, 0}, -- Green
    {0, 0, 1}, -- Blue
    {1, 1, 0}, -- Yellow
    {1, 0, 1}, -- Magenta
}

local grid = {}
local gridWidth, gridHeight = 10, 20
local blockSize = 30
local currentPiece
local currentColor
local pieceX, pieceY
local dropTimer, dropInterval = 0, 0.5
local gameOver = false
local score = 0
local sounds = {}
local isPaused = false
local saveFileName = "tetris_save.txt"
local message = ""
local messageTimer = 0
local messageDuration = 5 -- seconds

local function saveGame()
    local file = love.filesystem.newFile(saveFileName, "w")
    if file then
        file:write("score=" .. score .. "\n")
        file:write("pieceX=" .. pieceX .. "\n")
        file:write("pieceY=" .. pieceY .. "\n")
        
        -- Convert currentPiece to a flat string
        local pieceString = ""
        for _, block in ipairs(currentPiece) do
            pieceString = pieceString .. block[1] .. "," .. block[2] .. ";"
        end
        file:write("currentPiece=" .. pieceString .. "\n")
        
        -- Convert currentColor to a flat string
        local colorString = table.concat(currentColor, ",")
        file:write("currentColor=" .. colorString .. "\n")
        
        file:write("grid=")
        for y = 1, gridHeight do
            for x = 1, gridWidth do
                file:write(grid[y][x] .. ",")
            end
        end
        file:write("\n")
        file:close()
        
        message = "Game saved successfully!"
        messageTimer = messageDuration
    end
end

local function loadGame()
    if not love.filesystem.getInfo(saveFileName) then return end

    for line in love.filesystem.lines(saveFileName) do
        local key, value = line:match("([^=]+)=([^=]+)")
        if key == "score" then
            score = tonumber(value)
        elseif key == "pieceX" then
            pieceX = tonumber(value)
        elseif key == "pieceY" then
            pieceY = tonumber(value)
        elseif key == "currentPiece" then
            currentPiece = {}
            for block in value:gmatch("([^;]+)") do
                local x, y = block:match("([^,]+),([^,]+)")
                table.insert(currentPiece, { tonumber(x), tonumber(y) })
            end
        elseif key == "currentColor" then
            currentColor = {}
            for color in value:gmatch("([^,]+)") do
                table.insert(currentColor, tonumber(color))
            end
        elseif key == "grid" then
            local gridValues = {}
            for val in value:gmatch("([^,]+)") do
                table.insert(gridValues, tonumber(val))
            end
            local index = 1
            for y = 1, gridHeight do
                for x = 1, gridWidth do
                    grid[y][x] = gridValues[index]
                    index = index + 1
                end
            end
        end
    end
    
    message = "Game loaded successfully!"
    messageTimer = messageDuration
end

-- Helper functions
local function createGrid()
    for y = 1, gridHeight do
        grid[y] = {}
        for x = 1, gridWidth do
            grid[y][x] = 0
        end
    end
end

local function canPlacePiece(x, y, piece)
    for _, block in ipairs(piece) do
        local bx, by = x + block[1], y + block[2]
        if bx < 1 or bx > gridWidth or by < 1 or by > gridHeight or grid[by][bx] ~= 0 then
            return false
        end
    end
    return true
end

local function clearLines()
    local linesCleared = 0
    local y = gridHeight

    while y > 0 do
        local fullLine = true
        -- Check if line is full
        for x = 1, gridWidth do
            if grid[y][x] == 0 then
                fullLine = false
                break
            end
        end
        if fullLine then
            -- Move all lines above down
            for moveY = y, 2, -1 do
                grid[moveY] = grid[moveY - 1]
            end
            -- Create new empty line at top
            grid[1] = {}
            for x = 1, gridWidth do
                grid[1][x] = 0
            end
            linesCleared = linesCleared + 1
            -- Stay on same y since we moved everything down
            -- and need to check this row again
        else
            -- Only move to next row if we didn't clear a line
            y = y - 1
        end
    end
    if linesCleared > 0 then
        score = score + linesCleared * 100
        -- sounds.clear:play()
    end
end

local function spawnPiece()
    currentPiece = shapes[love.math.random(#shapes)]
    currentColor = colors[love.math.random(#colors)]
    pieceX, pieceY = math.floor(gridWidth / 2), 1
    if not canPlacePiece(pieceX, pieceY, currentPiece) then
        gameOver = true
    end
end

local function lockPiece()
    for _, block in ipairs(currentPiece) do
        local bx, by = pieceX + block[1], pieceY + block[2]
        grid[by][bx] = 1
    end
    clearLines()
    spawnPiece()
end

local function rotatePiece()
    local newPiece = {}
    for _, block in ipairs(currentPiece) do
        table.insert(newPiece, { -block[2], block[1] })
    end
    if canPlacePiece(pieceX, pieceY, newPiece) then
        currentPiece = newPiece
        -- sounds.rotate:play()
    end
end

local function restartGame()
    createGrid()
    score = 0
    gameOver = false
    spawnPiece()
end

-- Löve callbacks
function love.load()
    love.window.setMode(gridWidth * blockSize, gridHeight * blockSize)
    love.graphics.setBackgroundColor(0, 0, 0)

    -- sounds.move = love.audio.newSource("move.wav", "static")
    -- sounds.rotate = love.audio.newSource("rotate.wav", "static")
    -- sounds.drop = love.audio.newSource("drop.wav", "static")
    -- sounds.clear = love.audio.newSource("clear.wav", "static")

    createGrid()
    spawnPiece()
end

function love.update(dt)
    if gameOver or isPaused then return end

    dropTimer = dropTimer + dt
    if dropTimer >= dropInterval then
        dropTimer = 0
        if canPlacePiece(pieceX, pieceY + 1, currentPiece) then
            pieceY = pieceY + 1
        else
            lockPiece()
            -- sounds.drop:play()
        end
    end
    
    if messageTimer > 0 then
        messageTimer = messageTimer - dt
    end
end

local function drawMessageWithBackground(text, x, y, width, height)
    -- Draw background rectangle
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x - 10, y - 5, width, height)
    
    -- Draw border
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("line", x - 10, y - 5, width, height)
    
    -- Draw text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(text, x, y)
end

function love.draw()
    -- Draw grid
    for y = 1, gridHeight do
        for x = 1, gridWidth do
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("line", (x - 1) * blockSize, (y - 1) * blockSize, blockSize, blockSize)
            if grid[y][x] ~= 0 then
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("fill", (x - 1) * blockSize, (y - 1) * blockSize, blockSize, blockSize)
                love.graphics.setColor(0, 0, 0)
                love.graphics.rectangle("line", (x - 1) * blockSize, (y - 1) * blockSize, blockSize, blockSize)
            end
        end
    end

    -- Draw current piece
    if not gameOver then
        for _, block in ipairs(currentPiece) do
            local bx, by = pieceX + block[1], pieceY + block[2]
            love.graphics.setColor(currentColor)
            love.graphics.rectangle("fill", (bx - 1) * blockSize, (by - 1) * blockSize, blockSize, blockSize)
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("line", (bx - 1) * blockSize, (by - 1) * blockSize, blockSize, blockSize)
        end
    end

    -- Draw score with background
    drawMessageWithBackground("Score: " .. score, 10, 10, 100, 25)

    -- Draw game over messages with background
    if gameOver then
        drawMessageWithBackground("Game Over", 
            gridWidth * blockSize / 2 - 40, 
            gridHeight * blockSize / 2, 
            120, 30)
            
        drawMessageWithBackground("Press R to restart", 
            gridWidth * blockSize / 2 - 50, 
            gridHeight * blockSize / 2 + 40, 
            140, 30)
    end

    -- Draw pause menu with background
    if isPaused then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, gridWidth * blockSize, gridHeight * blockSize)

        local menuX = gridWidth * blockSize / 2 - 60
        local menuY = gridHeight * blockSize / 2 - 60
        
        drawMessageWithBackground("PAUSED", 
            menuX, menuY, 
            120, 30)
            
        drawMessageWithBackground("Press S to save game", 
            menuX, menuY + 40, 
            160, 30)
            
        drawMessageWithBackground("Press L to load game", 
            menuX, menuY + 80, 
            160, 30)
            
        drawMessageWithBackground("Press ESC to resume", 
            menuX, menuY + 120, 
            160, 30)
    end

    -- Draw save/load message
    if messageTimer > 0 then
        drawMessageWithBackground(message, 
            gridWidth * blockSize / 2 - 60, 
            gridHeight * blockSize / 2 - 100, 
            200, 30)
    end
end

function love.keypressed(key)
    if key == "escape" then
        isPaused = not isPaused
        if not isPaused then
            messageTimer = 0
        end
        return
    end
    
    if isPaused then
        if key == "s" then
            saveGame()
        elseif key == "l" then
            loadGame()
        end
        return
    end

    if gameOver then
        if key == "r" then
            restartGame()
        end
        return
    end

    if key == "left" and canPlacePiece(pieceX - 1, pieceY, currentPiece) then
        pieceX = pieceX - 1
        -- sounds.move:play()
    elseif key == "right" and canPlacePiece(pieceX + 1, pieceY, currentPiece) then
        pieceX = pieceX + 1
        -- sounds.move:play()
    elseif key == "down" and canPlacePiece(pieceX, pieceY + 1, currentPiece) then
        pieceY = pieceY + 1
        -- sounds.move:play()
    elseif key == "up" then
        rotatePiece()
    elseif key == "space" then
        while canPlacePiece(pieceX, pieceY + 1, currentPiece) do
            pieceY = pieceY + 1
        end
        lockPiece()
        -- sounds.drop:play()
    end
end

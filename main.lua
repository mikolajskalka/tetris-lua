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

-- Add this function to save the game state
local function saveGame()
    local saveData = {
        grid = grid,
        score = score,
        currentPiece = currentPiece,
        currentColor = currentColor,
        pieceX = pieceX,
        pieceY = pieceY
    }
    local serialized = love.data.encode('string', 'base64', love.data.compress('string', 'zlib', love.serialization.serialize(saveData)))
    love.filesystem.write(saveFileName, serialized)
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
    for y = gridHeight, 1, -1 do
        local fullLine = true
        for x = 1, gridWidth do
            if grid[y][x] == 0 then
                fullLine = false
                break
            end
        end
        if fullLine then
            table.remove(grid, y)
            table.insert(grid, 1, {})
            for x = 1, gridWidth do
                grid[1][x] = 0
            end
            linesCleared = linesCleared + 1
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

-- Add this function to load the game state
local function loadGame()
    if love.filesystem.getInfo(saveFileName) then
        local content = love.filesystem.read(saveFileName)
        local decoded = love.data.decode('string', 'base64', content)
        local decompressed = love.data.decompress('string', 'zlib', decoded)
        local saveData = love.serialization.deserialize(decompressed)
        
        grid = saveData.grid
        score = saveData.score
        currentPiece = saveData.currentPiece
        currentColor = saveData.currentColor
        pieceX = saveData.pieceX
        pieceY = saveData.pieceY
        gameOver = false
        isPaused = false
    end
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
end

function love.keypressed(key)
    if key == "escape" then
        isPaused = not isPaused
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

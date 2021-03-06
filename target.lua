--[[
Authors: Shing Yip, Ava Yip, Natalie Yip
]]

local object = require("object")

local fireImg = gfx.newImage("graphics/circle.png")
local Target = object:prototype()

function Target:__init()
    self.running = true
    self.font = self.font or scene.fonts[math.random(1, #scene.fonts)]
    self.textWidth = self.font:getWidth(self.word.spell)
    self.textHeight = self.font:getHeight(self.word.spell)
    self.color = self.color or scene.targetColors[math.random(1, #scene.targetColors)]
    self.speed = self.speed or scaleFactor*math.random(scene.level.speed.min, scene.level.speed.max)
    self.partialHitLength = 0
    self.hitCount = 0
    self.flame = 0

    self:setShape(phys.newRectangleShape(self.textWidth, self.textHeight))
    self:addToWorld(scene.world, math.random(10, screenWidth - 10), 10, "dynamic")
    self.body:setMass(10)
    self.fixture:setRestitution(0.5*scaleFactor)

    local ps = gfx.newParticleSystem(fireImg, 100)
    ps:setColors({255, 128, 32, 255}, {222, 128, 32, 255}, {128, 32, 32, 32}, {90, 12, 12, 92}, {32, 32, 32, 0})
    ps:setDirection(math.rad(90))
    ps:setEmissionRate(500*scaleFactor)
    ps:setEmitterLifetime(-1)
    ps:setInsertMode("bottom")
    ps:setLinearAcceleration(0, 0, 0, -100*scaleFactor)
    ps:setParticleLifetime(1, 3)
    ps:setRadialAcceleration(0, 0)
    ps:setRotation(0, math.rad(360))
    ps:setSizeVariation(0)
    ps:setSizes(1, 1, 1, 1, 0.75, 0.5, 0.25)
    ps:setSpeed(0, 50*scaleFactor)
    ps:setSpin(math.rad(0), math.rad(360))
    ps:setSpinVariation(1)
    ps:setSpread(math.rad(360))
    ps:setTangentialAcceleration(0, 0)
    self.flamePartSys = ps

    scheduler.start(self.inputChangeRoutine, self)

    return self
end

function Target:draw()
    local x, y = self.body:getWorldPoint(-self.textWidth/2, -self.textHeight/2)
    local flameScale = self.textWidth/80
    --logInfo("%s at %f,%f flameScale=%f", self.word.spell, x, y, flameScale)

    if self.flame >= 1 then
        local flameSpread = (self.textWidth*self.flame/scene.maxflame)/2
        self.flamePartSys:setAreaSpread("uniform", flameSpread, 0)
        local xx, yy =self.body:getWorldPoint(0,-self.textHeight/2)
        gfx.draw(self.flamePartSys, xx, yy, 0, flameScale, flameScale, self.body:getAngle())
    end

    -- draw the bounding box
    --[[
  gfx.setColor(255,255,0, 128)
  local boxX1, boxY1, boxX2, boxY2, boxX3, boxY3, boxX4, boxY4 = self.body:getWorldPoints(self.shape:getPoints())
  gfx.polygon("fill",
    boxX1 - 5, boxY1 - 2,
    boxX2 + 5, boxY2 - 3,
    boxX3 + 5, boxY3 + 2,
    boxX4 - 5, boxY4 + 3)
  ]]

    gfx.setFont(self.font)
    local textColor
    if self.hitCount > 1 then
        textColor = scene.targetHitColors[2]
    elseif self.hitCount > 0 then
        textColor = scene.targetHitColors[1]
    else
        textColor = self.color
    end
    gfx.setColor(textColor)
    gfx.print(self.word.spell, x, y, self.body:getAngle())

    if self.partialHitLength > 0 then
        local highlightedText = self.word.spell:sub(1, self.partialHitLength)
        local highlightColor = {
            textColor[1] > 200 and 0 or 255,
            200,
            (textColor[3] + 150) % 255,
            180}
        gfx.setColor(highlightColor)
        gfx.print(highlightedText, x, y, self.body:getAngle())
    end
end

function Target:update(dt)
    self.body:applyForce(0, self.speed)
    self.flamePartSys:update(dt)
end

function Target:inputChangeRoutine()
    while self.running do
        local input = scheduler:waitEvent("input")
        --logInfo("%s input %s", self.word.spell, input)
        self.partialHitLength = 0
        if string.sub(self.word.spell, 1, string.len(input)) == input then
            self.partialHitLength = string.len(input)
        end
    end
end

function Target:flamingRoutine()
    for i = 1, scene.maxflame do
        if self.hitCount > 0 then
            self.flame = 0
            return
        end
        self.flame = i
        scheduler:waitSeconds(scene.level.flameSpreadSpeed or 2)
    end
end

function Target:bounce()
    local speed = math.abs(self.speed)
    local bounceForce = speed*1000*scaleFactor
    self.body:applyForce(math.random(-bounceForce, bounceForce),
        math.random(-speed*10*bounceForce, 0))
    self.speed = math.min(-speed*1.5, -200*scaleFactor)
end

function Target:hitTest(text)
    if self.word.spell == text then
        scene.audio.hit:stop()
        scene.audio.hit:play()
        self:bounce()
        self.hitCount = self.hitCount + 1
        self.word.hitCount = self.word.hitCount + 1
        self.flame = 0
        return self.hitCount == 1 -- only return true on first hit
    end
    return false
end

function Target:onHitGround()
    logInfo("%s hitGround", self.word.spell)
    if not self.hitGround then
        self.hitGround = true
        scheduler.start(self.flamingRoutine, self)
        scene.audio.explosion:stop()
        scene.audio.explosion:play()
    end
end

return Target

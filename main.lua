print("Test")

SCREEN_UNITS_X = 640
SCREEN_UNITS_Y = 480
SCREEN_WIDTH = SCREEN_UNITS_X
SCREEN_HEIGHT = SCREEN_UNITS_Y

BASEX = 0
BASEY = -240

MIN_ENEMY_SPEED = 200
MAX_ENEMY_SPEED = 300

ALLY_SPEED = 300

function angle(x1, y1, x2, y2)
  return math.atan2(y2 - y1, x1 - x1) * (180 / math.pi)
end

function distance(x1, y1, x2, y2)
  return math.sqrt(((x2 - x1) ^ 2) + ((y2 - y1) ^ 2))
end

MOAISim.openWindow("Rocket", SCREEN_WIDTH, SCREEN_HEIGHT)

viewport = MOAIViewport.new()
viewport:setScale(640, 480)
viewport:setSize(640, 480)

layer = MOAILayer2D.new()
layer:setViewport(viewport)
MOAISim.pushRenderPass(layer)

lobsterGfx = MOAIGfxQuad2D.new()
lobsterGfx:setTexture("openlobster.png")
lobsterGfx:setRect(-128, -128, 128, 128)

base = MOAIProp2D.new()
base:setDeck(lobsterGfx)
base:setLoc(BASEX, BASEY)
layer:insertProp(base)

explosionGfx = MOAIGfxQuad2D.new()
explosionGfx:setTexture("fire.png")
explosionGfx:setRect(-32, -32, 32, 32)

function makeExplosion(x, y, size)
  local explosion = MOAIProp2D.new()
  explosion:setDeck(explosionGfx)
  explosion:setLoc(x, y)
  explosion.size = size
  layer:insertProp(explosion)

  function explosion:checkHit(prop)
    local x1, y1 = self:getLoc()
    local x2, y2 = prop:getLoc()
    return distance(x1, y1, x2, y2) <= self.size
  end

  function explosion:main()
    for i = 1, self.size do
      self:setFrame(-i, -i, i, i)

      for rocket in pairs(enemyRockets) do
        if self:checkHit(rocket) then
          rocket:explode(64)
        end
      end

      coroutine.yield()
    end
    layer:removeProp(self)
  end

  explosion.thread = MOAIThread.new()
  explosion.thread:run(explosion.main, explosion)
end

rocketGfx = MOAIGfxQuad2D.new()
rocketGfx:setTexture("rocket.png")
rocketGfx:setRect(-32, -32, 32, 32)

gameOver = false
enemyRockets = {}

function makeRocket(isAlly, startX, startY, targetX, targetY, speed)

  local travelDist = distance(startX, startY, targetX, targetY)
  local travelTime = travelDist / speed

  local rocket = MOAIProp2D.new()
  rocket:setDeck(rocketGfx)
  layer:insertProp(rocket)

  rocket:setLoc(startX, startY)
  rocket:setRot(angle(startX, startY, targetX, targetY) + 90)
  rocket.isAlly = isAlly

  if not isAlly then
    enemyRockets[rocket] = rocket
  end

  function rocket:explode(size)
    local x, y = self:getLoc()
    local explosion = makeExplosion(x, y, size)

    layer:removeProp(self)
    enemyRockets[self] = nil
    self.thread:stop()
  end

  function rocket:main()
    MOAICoroutine.blockOnAction(self:seekLoc(targetX, targetY, travelTime, MOAIEaseType.LINEAR))

    if self.isAlly then
      self:explode(64)
    else
      self:explode(128)
      gameOver = true
      layer:removeProp(base)
    end
  end

  rocket.thread = MOAIThread.new()
  rocket.thread:run(rocket.main, rocket)
end

function launchEnemyRocket(startX, startY)
  makeRocket(false, startX, startY, BASEX, BASEY, math.random(MIN_ENEMY_SPEED, MAX_ENEMY_SPEED))
end

function launchAllyRocket(targetX, targetY)
  makeRocket(true, BASEX, BASEY, targetX, targetY, ALLY_SPEED)
end

mainThread = MOAIThread.new()
mainThread:run(
  function()
    local frames = 0
    while not gameOver do
      coroutine.yield()
      frames = frames + 1
      if frames >= 90 then
        frames = 0
        launchEnemyRocket(math.random(-160, 160), 300)
      end
      if MOAIInputMgr.device.mouseLeft:down() then
        launchAllyRocket(layer:wndToWorld(MOAIInputMgr.device.pointer:getLoc()))
      end
    end

    local font = MOAIFont.new()
    font:loadFromTTF("arialbd.ttf", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.?!", 12, 163)

    local textbox = MOAITextBox.new()
    textbox:setFont(font)
    textbox:setTextSize(14)
    textbox:setRect(-160, -80, 160, 80)
    textbox:setAlignment(MOAITextBox.CENTER_JUSTIFY)
    textbox:setYFlip(true)
    textbox:setString("You are dead!")

    layer:insertProp(textbox)
    textbox:spool()
  end
)

local FissionReactor = require("reactor")
local sides = require("sides")
local event = require("event")
local rc = require("rc")
local reactors = {}
local isControllerRunning = false
local rodsToInsert = 0
local timer

function start()
  -- Initialize the reactor objects
  table.insert(reactors, FissionReactor.new("4b1a", "4e05"))
  table.insert(reactors, FissionReactor.new("721a", "9212"))
  table.insert(reactors, FissionReactor.new("7f00", "5f16"))
  table.insert(reactors, FissionReactor.new("6a34", "fcfd"))

  -- Configure reactors 3 and 4 (mirrored to the default)
  reactors[3].configureComponentSides(sides.east, sides.west, sides.south, sides.south, sides.up)
  reactors[4].configureComponentSides(sides.east, sides.west, sides.south, sides.south, sides.up)

  -- Enable spent fuel removal for all reactors
  for _, r in ipairs(reactors) do
    r.resetSpentFuelRemoval()
  end
  -- Set timer to run a spent fuel check every 2 seconds
  timer = event.timer(2, fuelTimerEventHandler, math.huge)
end

function stop()
  -- Stop the timer
  event.cancel(timer)
  rc.unload("reactor")
  rc.unload("controller")
end

function loadfuel(rods)
  if isControllerRunning then
    rodsToInsert = rods
    print("Setting the controller to load " .. rods .. " into each reactor.")
  else
    print("The controller is not running.")
  end
end

function fuelTimerEventHandler()
  for _, r in ipairs(reactors) do
    r.handleSpentFuelRods()
    if rodsToInsert > 0 then
      r.insertRods(rodsToInsert - r.getRodsInReactor())
    end
  end
end

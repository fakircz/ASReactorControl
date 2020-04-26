local FissionReactor = require("reactor")
local sides = require("sides")
local event = require("event")
local rc = require("rc")
local reactors = {}
local cycleInterval = 2
local isControllerRunning = false
local rodsToInsert = 0
local timer

function start()
  print("Initializing reactors...")
  -- Initialize the reactor objects
  table.insert(reactors, FissionReactor.new("4b1a", "4e05"))
  table.insert(reactors, FissionReactor.new("721a", "9212"))
  table.insert(reactors, FissionReactor.new("7f00", "5f16"))
  table.insert(reactors, FissionReactor.new("6a34", "fcfd"))

  -- Configure reactors 3 and 4 (mirrored to the default)
  reactors[3].configureComponentSides(sides.east, sides.west, sides.south, sides.south, sides.up)
  reactors[4].configureComponentSides(sides.east, sides.west, sides.south, sides.south, sides.up)
  print("Done.")

  -- Enable spent fuel removal for all reactors
  print("Resetting spent fuel retrievers...")
  for _, r in ipairs(reactors) do
    r.resetSpentFuelRemoval()
  end
  print("Done.")

  -- Set timer to run a spent fuel check every 2 seconds
  print("Setting the fuel handling cycle to " .. cycleInterval .. " seconds...")
  timer = event.timer(cycleInterval, fuelTimerEventHandler, math.huge)
  print("Done.")

  isControllerRunning = true
end

function stop()
  if isControllerRunning then
    print("Stopping reactor controller...")
    event.cancel(timer)
    rc.unload("reactor")
    rc.unload("controller")
    print("Done.")
  else
    print("The controller is not running.")
  end
end

function loadfuel()
  if isControllerRunning then
    local rods = 10  -- HACK
    rodsToInsert = rods
    print("Setting the controller to load " .. rods .. " into each reactor.")
  else
    print("The controller is not running.")
  end
end

-- Shuts down all reactors by removing all fuel rods.
function shutdown()
  if isControllerRunning then
    for _, r in ipairs(reactors) do
      if r.getRodsInReactor > 0 then
        r.removeAllRods()
      end
    end
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

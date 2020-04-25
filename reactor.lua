local component = require("component")
local sides = require("sides")

local FissionReactor = {}

FissionReactor.new = function(tp_addr, rs_addr)
  local self = {}

  local fuelId = "atomicscience:fissile_fuel_cell"
  local db = component.database
  local dbSpentSlot = 1
  local interfaceFuelSlot = 1
  local maxFuelRods = 10
  local rodsInside = 0
  local spentRemovalEnabled = false
  local usePartiallySpentRods = true
  
  local tp = component.proxy(component.get(tp_addr))
  local rs = component.proxy(component.get(rs_addr))
  
  --  Transposer side definitions
  local tpSides = {
    reactor = sides.west,
    iface = sides.south,
    spent = sides.east
  }
  
  -- Redstone IO side definitions
  local rsSides = {
    normal = sides.south,
    all = sides.up
  }
  
  function self.configureComponentSides(tp_reactor_side, tp_spent_side, tp_iface_side, rs_norm_side, rs_all_side)
    tpSides.reactor = tp_reactor_side
    tpSides.spent = tp_spent_side
    tpSides.iface = tp_iface_side
    rsSides.normal = rs_norm_side
    rsSides.all = rs_all_side
  end

  function self.getAddresses()
    return tp.address, rs.address
  end
  
  function self.getMaxFuelRods()
    return maxFuelRods
  end

  function self.getRodsInReactor()
    return rodsInside
  end
  
  function self.setMaxFuelRods(newValue)
    maxFuelRods = newValue
    return maxFuelRods
  end
  
  local function isFuelAvailable(count)
    local stack = tp.getStackInSlot(tpSides.iface, interfaceFuelSlot)
    return stack.name == fuelId and stack.size >= count
  end
  
  local function getPartiallySpentRodStacks()
    local psStacks = {}
    local currentStack
    local slot = 1
    
    -- Check all populated stacks in row (breaks on a first empty slot) to see
    -- if the item is a fuel rod and if it is NOT a fully spent rod.
    -- If so, insert the slot number to a list along with the amount if rods in that slot.
    repeat
      currentStack = tp.getStackInSlot(tpSides.spent, slot)
      if currentStack ~= nil then
        if currentStack.name == fuelId and not
        tp.compareStackToDatabase(tpSides.spent, slot, db.address, dbSpentSlot, true) then
          table.insert(psStacks, {size = currentStack.size, slot = slot})
        end
      end
      slot = slot + 1
    until currentStack == nil
    return psStacks
  end

  function self.insertRods(count)
    if count > maxFuelRods then
      count = maxFuelRods
    end
    -- Use partially spent rods first if enabled and available
    local lastInventorySlot = 1
  
    if usePartiallySpentRods then
      local psrStacks = getPartiallySpentRodStacks()

      if next(psrStacks) ~= nil then
        for i, psStack in ipairs(psrStacks) do
          local rodsInserted = tp.transferItem(tpSides.spent, tpSides.reactor, psStack.size, psStack.slot, i)
          rodsInside = rodsInside + rodsInserted
          lastInventorySlot = i
        end
      end
    end
  
    if rodsInside < count then
      local freshRodsToAdd = count - rodsInside
      
      if isFuelAvailable(freshRodsToAdd) then
        local rodsInserted = tp.transferItem(tpSides.iface, tpSides.reactor, freshRodsToAdd, 1, lastInventorySlot + 1)
        rodsInside = rodsInside + rodsInserted
      else
        print("Error: no fuel rods available!")
      end
    end
  end

  function self.enableSpentFuelRemoval()
    if not spentRemovalEnabled then
      rs.setOutput(rsSides.normal, 15)
      spentRemovalEnabled = true
    end
  end

  function self.disableSpentFuelRemoval()
    if spentRemovalEnabled then
      rs.setOutput(rsSides.normal, 0)
      spentRemovalEnabled = false
    end
  end

  -- This will shut down the reactor by removing all the fuel inside
  function self.removeAllRods()
    self.disableSpentFuelRemoval()
    os.sleep(0.2)
    rs.setOutput(rsSides.all, 15)
  end

  function self.resetReactor( ... )
    -- body
  end
  -- Poll the chest for spent rods, and if found, dump them to AE network and update the rod count.
  -- This needs to be ran periodically until a better way of detection is found.
  function self.handleSpentFuelRods()
    if tp.compareStackToDatabase(tpSides.spent, 1, db.address, dbSpentSlot, true) then
      local spentRodCount = tp.transferItem(tpSides.spent, tpSides.iface, 64, 1, 9)
      rodsInside = rodsInside - spentRodCount
    end
  end

  return self
end
return FissionReactor

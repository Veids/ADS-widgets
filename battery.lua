local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local colors = require("utils.colors")
local icons = require("icons")

-- Replace with your path to ADS-widgets lib
local lib = require("widgets.bar.ads.lib")

local icon_class = icons.text.mdn

local charger_plugged

local batteryTechs = {
  [0] = "Unknown",
  [1] = "Li-ion",
  [2] = "Li-poly",
  [3] = "LiFePO_4",
  [4] = "Lead-acid",
  [5] = "Ni-Cd",
  [6] = "Ni-MH",
}

local batteryWidget = wibox.widget {
  {
    id = "indicator",
    widget = wibox.widget.textbox,
    font = icon_class.font .. " 12",
    text = icon_class.blank,
    aligh = "center"
  },
  widget = wibox.container.background,
  fg = colors.white,
  forced_width = 17,
  set_text = function(self, Percentage, Charger, State)
    local icon = nil
    if State == 4 then
      icon = icon_class.battery.battery_full
    else
      local pId = Percentage // 10 + 1
      if Charger then
        icon = icon_class.battery.charging[pId]
      else
        icon = icon_class.battery.discharging[pId]
      end
    end
    self.indicator.text = icon
  end
}

local batteries_widget = wibox.layout.fixed.vertical()
local batteries_table = {}

local batteryPopup = awful.popup{
    ontop = true,
    visible = false,
    shape = gears.shape.rounded_rect,
    border_width = 1,
    border_color = beautiful.bg_normal,
    width = 300,
    maximum_width = 300,
    offset = { y = 5 },
    widget = {
      batteries_widget,
      widget = wibox.container.margin,
      margins = 4
    }
}

batteryWidget:connect_signal("mouse::enter", function() batteryPopup.visible = true; batteryPopup:move_next_to(mouse.current_widget_geometry) end)
batteryWidget:connect_signal("mouse::leave", function() batteryPopup.visible = false end)

local BatteryItem = {}

function BatteryItem:new(data)
  local obj = {}
  obj.objectPath = objectPath

  setmetatable(obj, self)
  self.__index = self
  obj:init(data)
  return obj
end

function BatteryItem:init(data)
  self.widget = BatteryItem:buildWidget()
  self.data = data
  self:update(data)
end

function BatteryItem:update(data)
  if data == nil then return end
  for k, v in pairs(data) do
    self.data[k] = v

    if self.data.Type == 2 and (k == "Percentage" or (k == "State" and v == 4)) then
      if charger_plugged ~= nil and self.data.Percentage ~= nil then
        batteryWidget:set_text(self.data.Percentage, charger_plugged, self.data.State)
      end
    end

    if k == "NativePath" then
      self.widget.NativePath.text = "┌[" .. v .. "]"
    elseif k == "Percentage" then
      self.widget.Percentage.text = "├PCT:\t\t" .. tostring(v)
    elseif k == "Capacity" then
      self.widget.Capacity.text = "├Capacity:\t" .. string.format("%02.f%%", v)
    elseif k == "TimeToEmpty" and v ~= 0 then
      local time = lib.secondsToClock(v, true)
      self.widget.TTFE.text = "├TTE:\t\t" .. time
    elseif k == "TimeToFull" and v ~= 0 then
      local time = lib.secondsToClock(v, true)
      self.widget.TTFE.text = "├TTF:\t\t" .. time
    elseif k == "Voltage" then
      self.widget.Voltage.text = "├Voltage:\t" .. tostring(v)
    elseif (k == "Energy" or k == "EnergyFull" or k == "EnergyRate") and
           (self.data.Energy ~= nil and self.data.EnergyFull ~= nil and self.data.EnergyRate ~= nil) then
      self.widget.Energy.text = "├Energy (Wh):\t" .. string.format(
        "%.2f / %.2f / %.2f",
        self.data.Energy,
        self.data.EnergyFull,
        self.data.EnergyRate
      )
    elseif k == "Technology" then
      self.widget.Technology.text = "└Technology:\t" .. batteryTechs[v]
    end
  end
end

function BatteryItem.buildWidget()
  return wibox.widget{
    {
      id = "NativePath",
      widget = wibox.widget.textbox,
    },
    {
      id = "Percentage",
      widget = wibox.widget.textbox,
    },
    {
      id = "Capacity",
      widget = wibox.widget.textbox,
    },
    {
      id = "TTFE",
      widget = wibox.widget.textbox,
    },
    {
      id = "Voltage",
      widget = wibox.widget.textbox,
    },
    {
      id = "Energy",
      widget = wibox.widget.textbox,
    },
    {
      id = "Technology",
      widget = wibox.widget.textbox,
    },
    layout = wibox.layout.fixed.vertical
  }
end

awesome.connect_signal("subsystem::charger", function(plugged)
  charger_plugged = plugged
end)

awesome.connect_signal("subsystem::battery", function(updateType, devicePath, data)
  if updateType == "update" then
    if batteries_table[devicePath] == nil then
      batteries_table[devicePath] = BatteryItem:new(data)
      batteries_widget:add(batteries_table[devicePath].widget)
    else
      batteries_table[devicePath]:update(data)
    end
  elseif updateType == "remove" then
    batteryItem = batteries_table[devicePath]
    if batteryItem ~= nil then
      batteries_table[devicePath] = nil
      batteries_widget:remove_widgets(batteryItem.widget)
    end
  end
end)

return batteryWidget

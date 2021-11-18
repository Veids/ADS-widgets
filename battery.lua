local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local colors = require("utils.colors")
local icons = require("icons")

-- Replace with your path to ADS-widgets lib
local lib = require("widgets.bar.ads.lib")

local icon_class = icons.text.mdn

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

local batteryPopupWidget = wibox.widget{
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
  {
    {
      {
        id = "Graph",
        widget = wibox.widget.graph,
        max_value = 100,
        min_value = 0,
        steps_width = 2,
        steps_spacing = 1,
        forced_width = 200,
        color = "linear:0,0:0,20:0,#FF0000:0.3,#FFFF00:0.6," .. beautiful.fg_normal,
        background_color = "#00000000",
        border_color = colors.gray
      },
      widget = wibox.container.mirror,
      reflection = {horizontal = true},
    },
    widget = wibox.container.margin,
    margins = 4
  },
  layout = wibox.layout.fixed.vertical
}

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
      batteryPopupWidget,
      widget = wibox.container.margin,
      margins = 4
    }
}

batteryWidget:connect_signal("mouse::enter", function() batteryPopup.visible = true; batteryPopup:move_next_to(mouse.current_widget_geometry) end)
batteryWidget:connect_signal("mouse::leave", function() batteryPopup.visible = false end)

local function batteryPropertyChanged(t, k, v)
  if k == "charger_plugged" or k == "Percentage" or (k == "State" and v == 4) then
    if t.charger_plugged ~= nil and t.Percentage ~= nil then
      batteryWidget:set_text(t.Percentage, t.charger_plugged, t.State)
    end
  end

  if k == "NativePath" then
    batteryPopupWidget.NativePath.text = "┌[" .. v .. "]"
  elseif k == "Percentage" then
    batteryPopupWidget.Percentage.text = "├PCT:\t\t" .. tostring(v)
  elseif k == "Capacity" then
    batteryPopupWidget.Capacity.text = "├Capacity:\t" .. string.format("%02.f%%", v)
  elseif k == "TimeToEmpty" and v ~= 0 then
    local time = lib.secondsToClock(v, true)
    batteryPopupWidget.TTFE.text = "├TTE:\t\t" .. time
  elseif k == "TimeToFull" and v ~= 0 then
    local time = lib.secondsToClock(v, true)
    batteryPopupWidget.TTFE.text = "├TTF:\t\t" .. time
  elseif k == "Voltage" then
    batteryPopupWidget.Voltage.text = "├Voltage:\t" .. tostring(v)
  elseif (k == "Energy" or k == "EnergyFull" or k == "EnergyRate") and
         (t.Energy ~= nil and t.EnergyFull ~= nil and t.EnergyRate ~= nil) then
    batteryPopupWidget.Energy.text = "├Energy (Wh):\t" .. string.format(
      "%.2f / %.2f / %.2f",
      t.Energy,
      t.EnergyFull,
      t.EnergyRate
    )
  elseif k == "Technology" then
    batteryPopupWidget.Technology.text = "└Technology:\t" .. batteryTechs[v]
  end
end

local batteryInfo = lib.trackingTable(batteryPropertyChanged)

awesome.connect_signal("subsystem::charger", function(plugged)
  batteryInfo.charger_plugged = plugged
end)

awesome.connect_signal("subsystem::battery", function(batteryId, data)
  for k, v in pairs(data) do
    batteryInfo[k] = v
  end
end)

gears.timer{
  timeout = 100,
  call_now = false,
  autostart = true,
  callback = function()
    batteryPopupWidget:get_children_by_id("Graph")[1]:add_value(batteryInfo.Percentage)
  end
}

return batteryWidget

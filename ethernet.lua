local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local icons = require("icons")

-- Replace with your path to ADS-widgets lib
local lib = require("widgets.bar.ads.lib")

local icon_class = icons.text.mdn

local deviceStates = {
  [60] = "Need Auth",
  [100] = "Connected"
}

local lanWidget = wibox.widget {
  {
      id = "indicator",
      widget = wibox.widget.textbox,
      text = icon_class.blank,
      font = icon_class.font .. " 11",
      align = "center"
  },
  widget = wibox.container.background,
  forced_width = 15,
  fg = "#FFFFFF",
  set_text = function(self, n)
      if n ~= nil then
          self.indicator.text = n
      end
  end,
}


local lanFields = { "Interface", "IP", "GW", "HwAddress", "MTU", "Speed", "Driver" }
local function createLanDevice()
  local lanInfo = {layout = wibox.layout.fixed.vertical}
  for i = 1, #lanFields do
    table.insert(
      lanInfo,
      {
        id = lanFields[i],
        widget = wibox.widget.textbox
      }
    )
  end
  return wibox.widget(lanInfo)
end

local popupDevices = wibox.layout.fixed.vertical()
local devices = {}

local popup = awful.popup{
    ontop = true,
    visible = false,
    shape = gears.shape.rounded_rect,
    border_width = 1,
    border_color = beautiful.bg_normal,
    maximum_width = 300,
    offset = { y = 5 },
    widget = {
      popupDevices,
      margins = 4,
      widget = wibox.container.margin
    }
}

lanWidget:connect_signal("mouse::enter", function() popup.visible = true; popup:move_next_to(mouse.current_widget_geometry) end)
lanWidget:connect_signal("mouse::leave", function() popup.visible = false end)

local function processDeviceProperties(t, k, v)
  if (k == "Interface" or k == "State" or k == "InterfaceFlags") and (t.State ~= nil and t.InterfaceFlags ~= nil) then
    if deviceStates[t.State] == "Connected" and t.InterfaceFlags ~= 0 then
      t._link.menuItem.Interface.text = "┌[" .. tostring(t.Interface) .. "]"
      lanWidget:set_text(icon_class.ethernet_on)
      t._link.menuItem.IP.visible = true
      t._link.menuItem.GW.visible = true
      -- t._link.menuItem.HwAddress.visible = true
      t._link.menuItem.MTU.visible = true
      t._link.menuItem.Speed.visible = true
    else
      t._link.menuItem.Interface.text = "┌[" .. tostring(t.Interface) .. "] - disconnected"
      lanWidget:set_text(icon_class.ethernet_off)
      t._link.menuItem.IP.visible = false
      t._link.menuItem.GW.visible = false
      -- t._link.menuItem.HwAddress.visible = false
      t._link.menuItem.MTU.visible = false
      t._link.menuItem.Speed.visible = false
    end
  elseif k == "HwAddress" then
    t._link.menuItem.HwAddress.text = "├HwAddress:\t" .. v
  elseif k == "Mtu" then
    t._link.menuItem.MTU.text = string.format("├MTU:\t\t%d", 0)
  elseif k == "Speed" then
    t._link.menuItem.Speed.text = string.format("├Speed:\t\t%f Mb/s", v / 1024)
  elseif k == "Driver" then
    t._link.menuItem.Driver.text = "└Driver:\t\t" .. v
  end
end

local function processIP4Properties(t, k, v)
  if k == "AddressData" then
    v = v[1]
    t._link.menuItem.IP.text = "├IPv4:\t\t\t" .. string.format("%s/%d", v.address, v.prefix)
  elseif k == "Gateway" then
    t._link.menuItem.GW.text = "├GW:\t\t\t" .. v
  end
end

awesome.connect_signal(
  "subsystem::wired",
  function(
    devicePath,
    changeType,
    data
  )
    if changeType == "Dev.Wired" then
      changeType = "Dev"
    elseif changeType == "Destroy" then
      popupDevices:remove_widgets(devices[devicePath].menuItem)
      devices[devicePath] = nil
      return
    end

    if devices[devicePath] == nil then
      devices[devicePath] = {}

      devices[devicePath].Dev = lib.trackingTable(processDeviceProperties)
      devices[devicePath].Dev._link = devices[devicePath]

      devices[devicePath].IP4Config = lib.trackingTable(processIP4Properties)
      devices[devicePath].IP4Config._link = devices[devicePath]

      devices[devicePath].menuItem = createLanDevice()
      popupDevices:add(devices[devicePath].menuItem)
    end

    for k, v in pairs(data) do
      devices[devicePath][changeType][k] = v
    end
  end
)

return lanWidget

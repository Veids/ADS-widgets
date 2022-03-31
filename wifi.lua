local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local icons = require("icons")
local NM = require("lgi").NM
local naughty = require("naughty")
local colors = require("utils.colors")

-- Replace with your path to ADS-widgets lib
local lib = require("widgets.bar.ads.lib")
local network = require("subsystem.dbus.network")

local icon_class = icons.text.mdn
local icon_sizes = " 12"
local icon_font = "Material Design Icons 14"
local icon_font_ng = "Material Design Icons 18"
local text_font = "Roboto Sans 12"

local NM_802_11_AP_FLAGS_PRIVACY = 0x1
local NM_802_11_AP_SEC_KEY_MGMT_802_1X = 0x200
local NM_802_11_AP_SEC_KEY_MGMT_SAE = 0x400
local NM_802_11_AP_SEC_KEY_MGMT_OWE = 0x800
local NM_802_11_AP_SEC_KEY_MGMT_EAP_SUITE_B_192 = 0x2000

local connections = {}
local ConnectionType = {
  WiFi = "802-11-wireless",
  Vpn = "vpn",
  WireGuard = "wireguard"
}

local devicesNg = {}
local accessPoints = {}
local activeConnections_obj = {}

local function flags_to_security(flags, wpa_flags, rsn_flags)
  local str = ""
  if flags & NM_802_11_AP_FLAGS_PRIVACY ~= 0 and wpa_flags ~= 0 and rsn_flags ~= 0 then
    str = str .. " WEP"
  end

  if wpa_flags ~= 0 then
    str = str .. " WPA1"
  end
  if rsn_flags ~= 0 then
    if rsn_flags & NM_802_11_AP_SEC_KEY_MGMT_SAE ~= 0 then
      str = str .. " WPA3"
    elseif rsn_flags & NM_802_11_AP_SEC_KEY_MGMT_EAP_SUITE_B_192 ~= 0 then
      str = str .. " WPA3-E"
    elseif rsn_flags & NM_802_11_AP_SEC_KEY_MGMT_OWE then
      str = str .. " OWE"
    else
      str = str .. " WPA2"
    end
  end
  if (wpa_flags | rsn_flags) & NM_802_11_AP_SEC_KEY_MGMT_802_1X ~= 0 then
    str = str .. " 802.1X"
  end
  return (str:gsub( "^%s", ""))
end

local wifiSearchScript = "sh -c '~/.dotfiles/polybar/scripts/wifi.sh'"

local deviceStates = {
  [60] = "Need Auth",
  [100] = "Connected"
}

local popups = {}

local wifiWidget = wibox.widget {
  {
      id = "indicator",
      widget = wibox.widget.textbox,
      text = icon_class.blank,
      font = icon_class.font .. " 11",
      align = "center"
  },
  widget = wibox.container.background,
  forced_width = 15,
  -- fg = "#FFFFFF",
  set_text = function(self, n)
      if n ~= nil then
          self.indicator.text = n
      end
  end,
  buttons = awful.button({}, 1, function()
      popups.main.visible = false
      popups.onClick:move_next_to(mouse.current_widget_geometry)
      popups.onClick.visible = true
      -- awful.spawn(wifiSearchScript)
    end
  )
}

local wifiFields = { "Interface", "ESSID", "Security", "IP", "GW", "BSSID", "SignalLvl", "MTU", "BitRate", "Driver" }
local function createWifiDevice()
  local wifiInfo = {layout = wibox.layout.fixed.vertical}
  for i = 1, #wifiFields do
    table.insert(
      wifiInfo,
      {
        id = wifiFields[i],
        widget = wibox.widget.textbox
      }
    )
  end
  return wibox.widget(wifiInfo)
end

local popupDevices = wibox.layout.fixed.vertical()
local devices = {}

local popup = awful.popup{
    ontop = true,
    visible = false,
    shape = gears.shape.rounded_rect,
    border_width = 1,
    border_color = beautiful.bg_normal,
    fg = "#ffffff",
    -- bg = "#3b4350",
    opacity = 0.8,
    maximum_width = 300,
    offset = { y = 5 },
    widget = {
      popupDevices,
      margins = 4,
      widget = wibox.container.margin
    }
}
popups.main = popup

wifiWidget:connect_signal("mouse::enter", function() popup.visible = true; popup:move_next_to(mouse.current_widget_geometry) end)
wifiWidget:connect_signal("mouse::leave", function() popup.visible = false end)

local proxyWidget = {}

local wifiState = wibox.widget {
  widget = wibox.widget.textbox,
  {
    -- I know there's exists native checkbox
    -- but i didn't get the alignment i need
    id = "checkbox",
    text = icon_class.checkbox.checked,
    checked = true,
    updateState = function(self)
      if self.checked == true then self:set_text(icon_class.checkbox.checked)
      else self:set_text(icon_class.checkbox.unchecked) end
    end,
    buttons = awful.button({}, 1, function()
      self = proxyWidget.wifiState.checkbox
      state = not self.checked
      network.NM:setWirelessEnabled(state)
      self.checked = state
      self:updateState()
    end
    ),
    font = icon_font,
    align = "center",
    widget = wibox.widget.textbox
  },
  {
    text = " " .. icon_class.wifi[6],
    font = icon_font,
    align = "center",
    widget = wibox.widget.textbox
  },
  nil,
  layout = wibox.layout.fixed.horizontal
}
proxyWidget.wifiState = wifiState

proxyWidget.airplaneMode = wibox.widget {
  {
    -- I know there's exists native checkbox
    -- but i didn't get the alignment i need
    id = "checkbox",
    text = icon_class.checkbox.checked,
    checked = false,
    updateState = function(self)
      if self.checked == true then self:set_text(icon_class.checkbox.checked)
      else self:set_text(icon_class.checkbox.unchecked) end
    end,
    buttons = awful.button({}, 1, function()
      self = proxyWidget.airplaneMode.checkbox
      state = not self.checked

      -- TODO: remember previous states and restore them
      if state then
        network.NM:setWirelessEnabled(state)
        network.NM:setWwanEnabled(state)
      else
        network.NM:setWirelessEnabled(state)
        network.NM:setWwanEnabled(state)
      end
      self.checked = state -- TODO: Should get update data from dbus itself
      self:updateState()
    end
    ),
    font = icon_font,
    align = "center",
    widget = wibox.widget.textbox
  },
  {
    text = " " .. icon_class.airplane,
    font = icon_font,
    align = "center",
    widget = wibox.widget.textbox
  },
  nil,
  layout = wibox.layout.fixed.horizontal
}

proxyWidget.editConnections = wibox.widget {
  text = icon_class.edit,
  font = icon_font,
  align = "center",
  buttons = awful.button({}, 1, function()
    awful.spawn("nm-connection-editor")
  end),
  widget = wibox.widget.textbox
}

proxyWidget.searchBox = wibox.widget {
  {
    text = " Search ...",
    valign = "center",
    widget = wibox.widget.textbox
  },
  -- TODO: decrease rounding
  shape = gears.shape.rounded_rect,
  shape_border_width = dpi(1),
  shape_border_color = "#ffffff",
  -- bg = "#ffffff",
  widget = wibox.container.background
}

local toolbar = wibox.widget {
  {
    id = "toolLayout",
    wifiState,
    proxyWidget.airplaneMode,
    proxyWidget.searchBox,
    proxyWidget.editConnections,
    spacing = dpi(2),
    widget = wibox.layout.ratio.horizontal
  },
  forced_width = 300,
  widget = wibox.container.background,
}
-- I don't know an other way to align this properly
toolbar.toolLayout:set_ratio(1, 0.19)
toolbar.toolLayout:set_ratio(2, 0.19)
toolbar.toolLayout:set_ratio(3, 0.51)
toolbar.toolLayout:set_ratio(4, 0.11)

local activeConnections = wibox.widget {
  nil,
  layout = wibox.layout.fixed.vertical
}

-- I know there's a wibox.widget.separator but i can't get it working here
local lineSeparator = wibox.widget {
  text = "-----------------------",
  font = icon_font,
  fg = "#fffff50",
  align = "center",
  widget = wibox.widget.textbox,
}

local availableConnections = wibox.widget {
  nil,
  layout = wibox.layout.fixed.vertical
}

local onClickPopup = awful.popup{
  ontop = true,
  visible = false,
  shape = gears.shape.rounded_rect,
  border_width = 1,
  border_color = beautiful.bg_normal,
  fg = "#ffffff",
  opacity = 0.8,
  maximum_width = 300,
  offset = { y = 5 },
  widget = {
    {
      {
        toolbar,
        margins = dpi(4),
        widget = wibox.container.margin
      },
      bg = "#2F2E2E",
      widget = wibox.container.background,
    },
    {
      {
        {
          activeConnections,
          lineSeparator,
          availableConnections,
          layout = wibox.layout.fixed.vertical
        },
        margins = dpi(4),
        widget = wibox.container.margin,
      },
      bg = "#3B363650",
      widget = wibox.container.background
    },
    layout = wibox.layout.fixed.vertical
  }
}
popups.onClick = onClickPopup
onClickPopup:connect_signal("mouse::leave", function() onClickPopup.visible = false end)

local function processDeviceProperties(t, k, v)
  if (k == "Interface" or k == "State" or k == "InterfaceFlags") and (t.State ~= nil and t.InterfaceFlags ~= nil) then
    if deviceStates[t.State] == "Connected" and t.InterfaceFlags ~= 0 then
      t._link.menuItem.Interface.text = "┌[" .. tostring(t.Interface) .. "]"
      t._link.menuItem.ESSID.visible = true
      t._link.menuItem.Security.visible = true
      t._link.menuItem.IP.visible = true
      t._link.menuItem.BSSID.visible = true
      t._link.menuItem.SignalLvl.visible = true
      t._link.menuItem.MTU.visible = true
      t._link.menuItem.BitRate.visible = true
      t._link.menuItem.GW.visible = true
    else
      wifiWidget:set_text(icon_class.wifi[1])
      t._link.menuItem.Interface.text = "-[" .. tostring(t.Interface) .. "] - disconnected"
      t._link.menuItem.ESSID.visible = false
      t._link.menuItem.Security.visible = false
      t._link.menuItem.IP.visible = false
      t._link.menuItem.BSSID.visible = false
      t._link.menuItem.SignalLvl.visible = false
      t._link.menuItem.MTU.visible = false
      t._link.menuItem.BitRate.visible = false
      t._link.menuItem.GW.visible = false
    end
  elseif k == "Mtu" then
    t._link.menuItem.MTU.text = string.format("├MTU:\t\t\t%d", v)
  elseif k == "Bitrate" and (t._link.AP.MaxBitrate ~= nil) then
    t._link.menuItem.BitRate.text = "├BitRate (HW/AP):\t" .. string.format("%d/%d Mb/s", v // 1000, t._link.AP.MaxBitrate // 1000) -- 1000 because it looks better :)
  elseif k == "Driver" then
    t._link.menuItem.Driver.text = "└Driver:\t\t\t" .. v
  end
end

local function processAPProperties(t, k, v)
  if k == "MaxBitrate" and t._link.Dev.Bitrate ~= nil then
    t._link.menuItem.BitRate.text = "├BitRate (HW/AP):\t" .. string.format("%d/%d Mb/s", t._link.Dev.Bitrate // 1000, v // 1000) -- 1000 because it looks better :)
  elseif k == "Strength" and t._link.Dev.InterfaceFlags ~= 0 then
    t._link.menuItem.SignalLvl.text = string.format("├Signal LvL:\t\t%d%%", t.Strength)
    if v < 25 then
      wifiWidget:set_text(icon_class.wifi[2])
    elseif v < 50 then
      wifiWidget:set_text(icon_class.wifi[3])
    elseif v < 70 then
      wifiWidget:set_text(icon_class.wifi[4])
    elseif v < 85 then
      wifiWidget:set_text(icon_class.wifi[5])
    else
      wifiWidget:set_text(icon_class.wifi[6])
    end
  elseif (k == "Ssid" or k == "Frequency") and (t.Ssid ~= nil and t.Frequency ~= nil) then
    local channel = NM.utils_wifi_freq_to_channel(t.Frequency)
    local ssid_text = NM.utils_ssid_to_utf8(t.Ssid)
    t._link.menuItem.ESSID.text = "├SSID:\t\t\t" .. string.format("%s %.1f GHz/%d", ssid_text, t.Frequency / 1000, channel)
  elseif (k == "WpaFlags" or k == "RsnFlags" or k == "Flags") and (t.WpaFlags ~= nil and t.RsnFlags ~= nil and t.Flags ~= nil) then
    t._link.menuItem.Security.text = "├Security:\t\t" .. flags_to_security(t.Flags, t.WpaFlags, t.RsnFlags)
  elseif k == "HwAddress" then
    t._link.menuItem.BSSID.text = "├BSSID:\t\t\t" .. v
  end
end

local function processIP4Properties(t, k, v)
  if k == "AddressData" then
    v = v[1]
    if v == nil then
      t._link.menuItem.IP.text = "├IPv4:\t\t\t0/0"
    else
      t._link.menuItem.IP.text = "├IPv4:\t\t\t" .. string.format("%s/%d", v.address or "0", v.prefix or 0)
    end
  elseif k == "Gateway" then
    t._link.menuItem.GW.text = "├GW:\t\t\t" .. v
  end
end

awesome.connect_signal(
  "subsystem::wifi",
  function(
    devicePath,
    changeType,
    data
  )
    if changeType == "Destroy" then
      popupDevices:remove_widgets(devices[devicePath].menuItem)
      devices[devicePath] = nil
      return
    elseif changeType == "Discard IP4Config" and devices[devicePath] ~= nil then
      devices[devicePath]["IP4Config"]["AddressData"] = {"", 0}
      devices[devicePath]["IP4Config"]["Gateway"] = ""
      return
    end

    if devices[devicePath] == nil and changeType == "Dev" then
      -- First time met this device
      devices[devicePath] = {}

      devices[devicePath].Dev = lib.trackingTable(processDeviceProperties)
      devices[devicePath].Dev._link = devices[devicePath]

      devices[devicePath].AP = lib.trackingTable(processAPProperties)
      devices[devicePath].AP._link = devices[devicePath]

      devices[devicePath].IP4Config = lib.trackingTable(processIP4Properties)
      devices[devicePath].IP4Config._link = devices[devicePath]

      devices[devicePath].menuItem = createWifiDevice()
      popupDevices:add(devices[devicePath].menuItem)
    end

    if data ~= nil then
      for k, v in pairs(data) do
        devices[devicePath][changeType][k] = v
      end
    end
  end
)

local NetworkItem = {}

function NetworkItem:new(objectPath, data)
  local obj = {}
  obj.objectPath = objectPath

  setmetatable(obj, self)
  self.__index = self
  obj:init(data)
  return obj
end

function NetworkItem:init(data)
  self.name = data["connection"].id
  self.type = data["connection"].type
  self.widget = NetworkItem.buildWidget()
  
  if self.type == "802-11-wireless" then
    self.signal = 0
    if data['802-11-wireless-security'] ~= nil then
      self.security = "yes"
    end
  end

  self:refreshIcon()
  self:refreshName()
end

function NetworkItem:dispose()

end

function NetworkItem:update(updateType, data)
  if updateType == "AccessPoint" then
    for k, v in pairs(data) do
      if k == "Strength" then
        self:setSignal(v)
      end
    end
  end
end

function NetworkItem:setSignal(strength)
  self.signal = strength
  self:refreshIcon()
end

function NetworkItem:refreshIcon()
  local icon = "󰼇"
  if self.type == ConnectionType.WiFi then
    if self.security then
      if self.signal == 0 then
        icon = icon_class.WiFi["100-locked"]
      elseif self.signal < 25 then
        icon = icon_class.WiFi["25-locked"]
      elseif self.signal < 50 then
        icon = icon_class.WiFi["50-locked"]
      elseif self.signal < 75 then
        icon = icon_class.WiFi["75-locked"]
      else
        icon = icon_class.WiFi["100-locked"]
      end
    else
      if self.signal == 0 then
        icon = icon_class.WiFi["100"]
      elseif self.signal < 25 then
        icon = icon_class.WiFi["25"]
      elseif self.signal < 50 then
        icon = icon_class.WiFi["50"]
      elseif self.signal < 75 then
        icon = icon_class.WiFi["75"]
      else
        icon = icon_class.WiFi["100"]
      end
    end
  elseif self.type == ConnectionType.Vpn or self.type == ConnectionType.WireGuard then
    icon = icon_class.vpn
  end

  self.widget:get_children_by_id("icon")[1].text = icon
end

function NetworkItem:refreshName()
  self.widget:get_children_by_id("name")[1].text = self.name
end

function NetworkItem.buildWidget()
  local widget = wibox.widget {
    {
      {
        id = "icon",
        align = "center",
        font = icon_font_ng,
        widget = wibox.widget.textbox
      },
      {
        {
          id = "name",
          font = text_font,
          widget = wibox.widget.textbox
        },
        id = "ratio_name_speed",
        widget = wibox.layout.ratio.vertical
      },
      {
        id = "connect",
        font = text_font,
        widget = wibox.widget.textbox
      },
      id = "ratio_main",
      widget = wibox.layout.ratio.horizontal
    },
    widget = wibox.container.background
  }
  ratio_name_speed = widget:get_children_by_id("ratio_name_speed")[1]
  ratio_name_speed:set_ratio(1, 0.70)
  ratio_name_speed:set_ratio(2, 0.30)

  ratio_main = widget:get_children_by_id("ratio_main")[1]
  ratio_main:set_ratio(1, 0.10)
  return widget
end

local devicePattern = "^Device"
local wirelessPattern ="^Wireless"
local connectionPattern = "^Connection"
local activeConnectionPattern = "^ActiveConnection"
local accessPointPattern = "^AccessPoint"

local function connectionAdd(objectPath, data)
  if connections[objectPath] ~= nil then return end

  connections[objectPath] = NetworkItem:new(objectPath, data)
  return connections[objectPath].widget
end

local function handleConnection(signalType, objectPath, data)
  if signalType == "ConnectionAdd" then
    local widget = connectionAdd(objectPath, data)
    availableConnections:add(widget)
  elseif signalType == "ConnectionRemove" then
    local networkItem = connections[objectPath]
    if networkItem == nil then return end
    availableConnections:remove_widgets(networkItem.widget)
    networkItem:dispose()
    connections[objectPath] = nil
  elseif signalType == "ConnectionUpdate" then
    connections[objectPath]:update("Connection", data)
  end
end

local function handleDeviceAdd(objectPath, data)
  if data.Managed ~= true then return end
  if devicesNg[objectPath] == nil then return end
  devicesNg[objectPath] = {}
  devicesNg[objectPath].Device = data
end

local function handleDeviceRemove(objectPath)
  devicesNg[objectPath] = nil
end

local function handleDeviceUpdate(objectPath, data)
  if devicesNg[objectPath] == nil then return end
end

local function handleDevice(signalType, objectPath, data)
  if signalType == "DeviceAdd" then
    if NM.utils_enum_to_str(NM.DeviceType, data.DeviceType) ~= "wifi" then return end
    handleDeviceAdd(objectPath, data)
  elseif signalType == "DeviceRemove" then
    handleDeviceRemove(objectPath)
  elseif signalType == "DeviceUpdate" then
    handleDeviceRemove(objectPath, data)
  end
end

local function handleWirelessAdd(objectPath, data)
  devicesNg[objectPath].Wireless = data
end

local function handleWirelessUpdate(objectPath, data)
  if devicesNg[objectPath].Wireless == nil then return end
end

local function handleWireless(signalType, objectPath, data)
  if devicesNg[objectPath] == nil then return end

  if signalType == "WirelessAdd" then
    handleWirelessAdd(objectPath, data)
  elseif signalType == "WirelessUpdate" then
    handleWirelessUpdate(objectPath, data)
  end
end

local function getConnectionByAP(objectPath)
  for oP, v in pairs(activeConnections_obj) do
    if v.Type == ConnectionType.WiFi and v.SpecificObject == objectPath then
      return v.Connection
    end
  end
end

local function handleAccessPointAdd(objectPath, data)
  if accessPoints[objectPath] ~= nil then return end
  accessPoints[objectPath] = data

  local connection = getConnectionByAP(objectPath)
  if connection then
    accessPoints[objectPath]._link = connection
    connections[connection]:update("AccessPoint", data)
  end
end

local function handleAccessPointRemove(objectPath)
  accessPoints[objectPath] = nil
end

local function handleAccessPointUpdate(objectPath, data)
  if accessPoints[objectPath] == nil then return end
  for k, v in pairs(data) do
    accessPoints[objectPath][k] = v
  end

  local connection = accessPoints[objectPath]._link
  if connection then
    connections[connection]:update("AccessPoint", data)
  end
end

local function handleAccessPoint(signalType, objectPath, data)
  if signalType == "AccessPointAdd" then
    handleAccessPointAdd(objectPath, data)
  elseif signalType == "AccessPointRemove" then
    handleAccessPointRemove(objectPath)
  elseif signalType == "AccessPointUpdate" then
    handleAccessPointUpdate(objectPath, data)
  end
end

local function handleActiveConnectionAdd(objectPath, data)
  if activeConnections_obj[objectPath] ~= nil then return end
  activeConnections_obj[objectPath] = data

  if connections[data.Connection] then
    local widget = connections[data.Connection].widget
    availableConnections:remove_widgets(widget)
    activeConnections:add(widget)
    -- if data.Type == ConnectionType.WiFi then
    --   naughty.notify({text = data.SpecificObject})
    --   local ap = accessPoints[data.SpecificObject]
    --   naughty.notify({text = tostring(ap)})
    --   if ap and ap._link == nil then
    --     ap._link = data.Connection
    --     connections[data.Connection]:update("AccessPoint", ap)
    --   end
    -- end
  end
end

local function handleActiveConnectionRemove(objectPath)
  if activeConnections_obj[objectPath] then
    local connection = connections[activeConnections_obj[objectPath].Connection]
    -- some connections are not tracked, so we need to check existence
    if connection then
      activeConnections:remove_widgets(connection.widget)
      availableConnections:add(connection.widget)
    end
  end
  activeConnections_obj[objectPath] = nil
end

local function handleActiveConnectionUpdate(objectPath, data)
  if activeConnections_obj[objectPath] == nil then return end
  -- naughty.notify({text = gears.debug.dump_return(data)})
end

local function handleActiveConnection(signalType, objectPath, data)
  if signalType == "ActiveConnectionAdd" then
    handleActiveConnectionAdd(objectPath, data)
  elseif signalType == "ActiveConnectionRemove" then
    handleActiveConnectionRemove(objectPath)
  elseif signalType == "ActiveConnectionUpdate" then
    handleActiveConnectionUpdate(objectPath, data)
  end
end

awesome.connect_signal(
  "subsystem::nm",
  function(
    signalType,
    objectPath,
    data
  )
    if signalType:find(connectionPattern) ~= nil then
      handleConnection(signalType, objectPath, data)
    elseif signalType:find(activeConnectionPattern) ~= nil then
      handleActiveConnection(signalType, objectPath, data)
    elseif signalType:find(devicePattern) then
      handleDevice(signalType, objectPath, data)
    elseif signalType:find(wirelessPattern) then
      handleWireless(signalType, objectPath, data)
    elseif signalType:find(accessPointPattern) then
      handleAccessPoint(signalType, objectPath, data)
    end
  end
)

return wifiWidget

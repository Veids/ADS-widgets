local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local icons = require("icons")
local NM = require("lgi").NM

-- Replace with your path to ADS-widgets lib
local lib = require("widgets.bar.ads.lib")

local icon_class = icons.text.mdn
local NM_802_11_AP_FLAGS_PRIVACY = 0x1
local NM_802_11_AP_SEC_KEY_MGMT_802_1X = 0x200
local NM_802_11_AP_SEC_KEY_MGMT_SAE = 0x400
local NM_802_11_AP_SEC_KEY_MGMT_OWE = 0x800
local NM_802_11_AP_SEC_KEY_MGMT_EAP_SUITE_B_192 = 0x2000

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
      awful.spawn(wifiSearchScript)
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

wifiWidget:connect_signal("mouse::enter", function() popup.visible = true; popup:move_next_to(mouse.current_widget_geometry) end)
wifiWidget:connect_signal("mouse::leave", function() popup.visible = false end)

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

return wifiWidget

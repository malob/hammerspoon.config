-----------------------
-- HS initialization --
-----------------------

-- Load configuration constants
consts = require "configConsts"

-- Reload HS on changes in config dir
hs.pathwatcher.new(hs.configdir, hs.reload):start()

-- Spoon initialization
-- http://www.hammerspoon.org/Spoons/SpoonInstall.html
hs.loadSpoon("SpoonInstall")

-- http://www.hammerspoon.org/Spoons/KSheet.html
spoon.SpoonInstall:andUse("KSheet")

-- http://www.hammerspoon.org/Spoons/SpeedMenu.html
spoon.SpoonInstall:andUse("SpeedMenu")

-- https://github.com/miromannino/miro-windows-manager
-- http://www.hammerspoon.org/Spoons/MiroWindowsManager.html
hyper = {"ctrl", "alt", "cmd"}
spoon.SpoonInstall:andUse(
  "MiroWindowsManager",
  {
    hotkeys = {
      up = {hyper, "up"},
      right = {hyper, "right"},
      down = {hyper, "down"},
      left = {hyper, "left"},
      fullscreen = {hyper, "f"}
    }
  }
)
hs.window.animationDuration = 0.1

-- http://www.hammerspoon.org/Spoons/URLDispatcher.html
spoon.SpoonInstall:andUse(
  "URLDispatcher",
  {
    config = {url_patterns = consts.urlPatterns},
    start = true
  }
)

-- http://www.hammerspoon.org/Spoons/Seal.html
spoon.SpoonInstall:andUse(
  "Seal",
  {
    fn = function(x)
      x:loadPlugins({"apps", "calc", "useractions"})
      x.plugins.useractions.actions = {
        -- Audio devices commands
        ["Connect Beats"] = {
          fn = function()
            changeAudioDevice("Malo’s Beats Studio³")
          end
        },
        ["Connect AirPods"] = {
          fn = function()
            changeAudioDevice("Malo’s AirPods")
          end
        },
        ["Connect LG Display"] = {
          fn = function()
            changeAudioDevice("LG UltraFine Display Audio")
          end
        },
        ["Connect Built-in"] = {
          fn = function()
            hs.audiodevice.findInputByName("Built-in Microphone"):setDefaultInputDevice()
            hs.audiodevice.findOutputByName("Built-in Output"):setDefaultOutputDevice()
            hs.notify.show("Audio Device", "", "Built-in connected")
          end
        },
        -- TTS commands
        ["Pause/Play TTS"] = {
          fn = function()
            pauseOrContinueTts()
          end
        },
        ["Speak Text"] = {
          fn = function(x)
            speakText(x)
          end,
          keyword = "speak"
        },
        ["Add article to podcast"] = {
          fn = function(x)
            ttsPodcast(x)
          end,
          keyword = "ttspod"
        },
        -- Asana
        ["New Asana Task in MIRI"] = {
          url = "https://asana.com",
          fn = function(x)
            newAsanaTask(x, asanaWorkspaceIds["MIRI"])
          end,
          keyword = "amiri"
        },
        ["New Asana Task in Gerlo"] = {
          url = "https://asana.com",
          fn = function(x)
            newAsanaTask(x, asanaWorkspaceIds["Gerlo"])
          end,
          keyword = "agerlo"
        },
        -- System commands
        ["Restart/Reboot"] = {
          fn = function()
            hs.caffeinate.restartSystem()
          end
        },
        ["Shutdown"] = {
          fn = function()
            hs.caffeinate.shutdownSystem()
          end
        },
        ["Lock"] = {
          fn = function()
            hs.eventtap.keyStroke({"cmd", "ctrl"}, "q")
          end
        },
        ["Toggle Tethering"] = {
          fn = function()
            toggleTethering()
          end
        }
      }
      x:refreshAllCommands()
    end,
    start = true
  }
)

------------------
-- VPN and WiFi --
------------------
function toggleTethering()
  local wifiMenuItem = consts.hotspots[1]
  local delay = 5

  if hs.wifi.currentNetwork() == consts.hotspots[1] then
    wifiMenuItem = "Disconnect from " .. wifiMenuItem
    delay = 0
  end

  hs.osascript.applescript(
    string.format(
      [[
      tell application "System Events" to tell process "SystemUIServer"
  	    set wifi to (first menu bar item whose description contains "Wi-Fi") of menu bar 1
        click wifi
        delay %i
        click (first menu item whose title contains "%s") of menu of wifi
      end tell
      ]],
      delay,
      wifiMenuItem
    )
  )
end

function wifiChange(watcher, message, interface)
  local ssid = hs.wifi.currentNetwork(interface)

  if ssid and message == "SSIDChange" then
    hs.notify.show("WiFi", "", "Connected to " .. ssid)

    -- Connect/disconnect from VPN
    if hs.fnutils.contains(hs.fnutils.concat(consts.trustedNetworks, consts.hotspots), ssid) then
      local vpnApp = hs.application.get(consts.vpnApp)
      if vpnApp then
        vpnApp:kill9()
      end
    else
      hs.application.open(consts.vpnApp)
    end

    -- Hotspot specifc
    if hs.fnutils.contains(consts.hotspots, ssid) then
      hs.fnutils.ieach(
        consts.highBandwidthApps,
        function(x)
          app = hs.application.get(x)
          if app then
            app:kill()
          end
        end
      )
    else
      hs.fnutils.ieach(
        consts.highBandwidthApps,
        function(x)
          hs.application.open(x)
        end
      )
    end
  end
end

hs.wifi.watcher.new(wifiChange):start()

---------
-- TTS --
---------

-- Podcast
function ttsPodcast(url)
  if not url then
    hs.eventtap.keyStroke({"cmd"}, "c")
    url = hs.pasteboard.readString()
  end
  hs.notify.show("TTS Podcast", "", "Adding new article")
  local data = {["url"] = url}
  hs.http.asyncPost(
    consts.ttsPodcastUrl,
    hs.json.encode(data, true),
    {["Content-Type"] = "application/json"},
    function(code, response, headers)
      if code == 200 then
        hs.notify.show("TTS Podcast", "", "Article added successfully!")
      else
        hs.notify.show("TTS Podcast", "", "Error adding article!")
        print(response)
        hs.toggleConsole()
      end
    end
  )
end

hs.hotkey.bind({"cmd", "shift"}, hs.keycodes.map["escape"], ttsPodcast)

-- macOS TTS
ttsSynth = hs.speech.new(consts.osTtsVoice)
ttsSynth:rate(consts.osTtsRate)

function pauseOrContinueTts()
  if ttsSynth:isPaused() then
    ttsSynth:continue()
  else
    ttsSynth:pause()
  end
end

function speakText(textToSpeak)
  if not textToSpeak then
    hs.eventtap.keyStroke({"cmd"}, "c")
    textToSpeak = hs.pasteboard.readString()
  end
  if ttsSynth:isSpeaking() then
    ttsSynth:stop()
  else
    ttsSynth:speak(textToSpeak)
  end
end

hs.hotkey.bind("option", "escape", speakText)
hs.hotkey.bind({"option", "shift"}, "escape", pauseOrContinueTts)

----------------------------
-- Audio device functions --
----------------------------
function changeAudioDevice(deviceName)
  if hs.audiodevice.findDeviceByName(deviceName) then
    hs.audiodevice.findInputByName(deviceName):setDefaultInputDevice()
    hs.audiodevice.findOutputByName(deviceName):setDefaultOutputDevice()
  else
    hs.osascript.applescript(
      string.format(
        [[
        tell application "System Events" to tell process "SystemUIServer"
	        set vol to (first menu bar item whose description contains "Volume") of menu bar 1
          click vol
          delay 2
          click (first menu item whose title is "%s") of menu of vol
        end tell
        ]],
        deviceName
      )
    )
  end

  if hs.audiodevice.defaultOutputDevice():name() == deviceName then
    hs.notify.show("Audio Device", "", deviceName .. " connected")
  else
    hs.notify.show("Audio Device", "", "Failed to conncet to " .. deviceName)
  end
end

-----------
-- Asana --
-----------
asanaBaseUrl = "https://app.asana.com/api/1.0"
asanaHeader = {["Authorization"] = "Bearer " .. consts.asanaApiKey}
asanaUserId = nil
asanaWorkspaceIds = {}

hs.http.asyncGet(
  asanaBaseUrl .. "/users/me",
  asanaHeader,
  function(code, res, headers)
    res = hs.json.decode(res)
    asanaUserId = res.data.id
    hs.fnutils.each(
      res.data.workspaces,
      function(x)
        asanaWorkspaceIds[x.name] = x.id
      end
    )
  end
)

function newAsanaTask(taskName, workspace)
  local url =
    asanaBaseUrl .. "/tasks" .. "?assignee=" .. asanaUserId .. "&workspace=" .. workspace .. "&name=" .. taskName
  hs.http.asyncPost(
    url,
    "",
    asanaHeader,
    function(code, response, headers)
      if code == 201 then
        hs.notify.show("Asana", "", "New task added")
      else
        hs.notify.show("Asana", "", "Error adding task")
        print(response)
        hs.toggleConsole()
      end
    end
  )
end

----------
-- Seal --
----------

-- Get Seal to refocus last window when it closes
sealVisible = false
windowBeforeSeal = nil

function toggleSeal()
  if sealVisible then
    spoon.Seal:toggle()
    sealVisible = false
    windowBeforeSeal:focus()
    windowBeforeSeal = nil
  else
    windowBeforeSeal = hs.window.focusedWindow()
    spoon.Seal:toggle()
    sealVisible = true
  end
end

hs.hotkey.bind("cmd", "space", toggleSeal)

hs.notify.show("Hammerspoon", "", "Configuration (re)loaded")

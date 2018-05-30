-----------------------
-- HS initialization --
-----------------------

-- Load configuration constants used throughout the code
consts = require "configConsts"

-- Reload Hammerspoon on changes in config dir
hs.pathwatcher.new(hs.configdir, hs.reload):start()

-- Misc
hyper = {"ctrl", "alt", "cmd"}
hs.window.animationDuration = 0.1
hs.doc.hsdocs.forceExternalBrowser(true)

------------------
-- Spoons setup --
------------------

-- SpoonInstall, to manage installation and setup of all other spoons
-- http://www.hammerspoon.org/Spoons/SpoonInstall.html
hs.loadSpoon("SpoonInstall")

-- KSheet, keyboard shotcuts popup window (not currently using)
-- http://www.hammerspoon.org/Spoons/KSheet.html
spoon.SpoonInstall:andUse("KSheet")

-- SpeedMenu, shows upload and download rates in menubar
-- http://www.hammerspoon.org/Spoons/SpeedMenu.html
spoon.SpoonInstall:andUse("SpeedMenu")

-- Miro Windows Manager, easy window movement
-- https://github.com/miromannino/miro-windows-manager
-- http://www.hammerspoon.org/Spoons/MiroWindowsManager.html
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

-- URLDispatcher, for routing URLs do different apps based on patterns
-- http://www.hammerspoon.org/Spoons/URLDispatcher.html
spoon.SpoonInstall:andUse(
  "URLDispatcher",
  {
    config = {url_patterns = consts.urlPatterns},
    start = true
  }
)

-- Seal, a powerful launch bar
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
        -- Text-to-speach commands
        ["Pause/Play TTS"] = {
          fn = function()
            pauseOrContinueTts()
          end
        },
        ["Speak text"] = {
          fn = function(x)
            speakText(x)
          end,
          keyword = "speak"
        },
        ["Add article to TTS podcast"] = {
          fn = function(x)
            ttsPodcast(x)
          end,
          keyword = "ttspod"
        },
        -- Asana
        ["New Asana task in " .. consts.asanaWorkWorkspaceName] = {
          fn = function(x)
            newAsanaTask(x, consts.asanaWorkWorkspaceName)
          end,
          keyword = "awork"
        },
        ["New Asana task in " .. consts.asanaPersonalWorkspaceName] = {
          fn = function(x)
            newAsanaTask(x, consts.asanaPersonalWorkspaceName)
          end,
          keyword = "ahome"
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
        ["Toggle tethering"] = {
          fn = function()
            toggleTethering()
          end
        },
        ["Hammerspoon Docs"] = {
          fn = function(x)
            hs.doc.hsdocs.help(x)
          end,
          keyword = "hsdocs"
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

-- Toggle tethering for devices connected to iCloud account
-- Uses Applescript to manipulate the Wi-Fi menu item
function toggleTethering()
  local wifiMenuItem = consts.hotspots[1]
  local delay = 5 -- tethering options often don't appear in menu right away

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

-- Watches for SSID change
-- If network isn't trusted loads VPN application
-- If network is a hotspot kills high-bandwidth apps
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

----------------------------
-- Text-to-speech podcast --
----------------------------

-- Submits a url to an article to text-to-speach podcast generator
-- If url is nil as an argument then uses whatever text is currently selected
-- See https://github.com/malob/article-to-audio-cloud-function for info on the rest of the service
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

--------------------------
-- macOS text-to-speech --
--------------------------
ttsSynth = hs.speech.new(consts.osTtsVoice)
ttsSynth:rate(consts.osTtsRate)

function pauseOrContinueTts()
  if ttsSynth:isPaused() then
    ttsSynth:continue()
  else
    ttsSynth:pause()
  end
end

-- Speaks text using macOS text-to-speech
-- If textToSpeak is nil currently selected text is used
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

-- Switches audio input/output device
-- For some Bluetooth devices like AirPods they don't show up in list of available devices
-- For these devices, if not found in device list, Applescript is used to manipulate Volume menu item to connect them
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
          delay 3
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

-- Setup core constants
asana = {}
asana.baseUrl = "https://app.asana.com/api/1.0"
asana.reqHeader = {["Authorization"] = "Bearer " .. consts.asanaApiKey}
asana.userId = nil
asana.workspaceIds = {}

-- Get Asana userId and workspaceIds
function getAsanaIds()
  local code, res, headers = hs.http.get(asana.baseUrl .. "/users/me", asana.reqHeader)
  res = hs.json.decode(res)
  asana.userId = res.data.id
  hs.fnutils.each(
    res.data.workspaces,
    function(x)
      asana.workspaceIds[x.name] = x.id
    end
  )
end

-- Creates a new Asana task with a given name in a given workspace
-- First time function is called it retrieves IDs
function newAsanaTask(taskName, workspaceName)
  if not asana.userId then
    getAsanaIds()
  end
  hs.http.asyncPost(
    string.format(
      "%s/tasks?assignee=%i&workspace=%i&name=%s",
      asana.baseUrl,
      asana.userId,
      asana.workspaceIds[workspaceName],
      hs.http.encodeForQuery(taskName)
    ),
    "", -- requires empty body
    asana.reqHeader,
    function(code, res, headers)
      if code == 201 then
        hs.notify.show("Asana", "", "New task added to workspace: " .. workspaceName)
      else
        hs.notify.show("Asana", "", "Error adding task")
        print(res)
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

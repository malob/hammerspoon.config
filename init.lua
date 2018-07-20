-----------------------
-- HS initialization --
-----------------------

-- Load configuration constants used throughout the code
consts = require "configConsts"

-- Reload Hammerspoon on changes in config dir
reloadConfWatcher = hs.pathwatcher.new(hs.configdir, hs.reload):start()

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
spoon.SpoonInstall.use_syncinstall = true

-- KSheet, keyboard shortcuts popup window
-- http://www.hammerspoon.org/Spoons/KSheet.html
spoon.SpoonInstall:andUse("KSheet")
local ksheetVisible = false
function toggleKSheet()
  if ksheetVisible then
    spoon.KSheet:hide()
    ksheetVisible = false
  else
    spoon.KSheet:show()
    ksheetVisible = true
  end
end
hs.hotkey.bind(hyper, "/", toggleKSheet)

-- SpeedMenu, shows upload and download rates in menubar
-- http://www.hammerspoon.org/Spoons/SpeedMenu.html
-- spoon.SpoonInstall:andUse("SpeedMenu", {start = true})

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
    config = {
      default_handler = consts.defaultUrlHandler,
      url_patterns = consts.urlPatterns
    },
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
            refocusAfterUserAction()
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
        -- Text-to-speech commands
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
        ["Toggle dark mode"] = {
          fn = function()
            toggleDarkMode()
          end
        },
        ["Make a phone call"] = {
          fn = function(x)
            hs.urlevent.openURL("tel://" .. hs.http.encodeForQuery(x))
          end,
          keyword = "call"
        },
        ["Search in Maps"] = {
          fn = function(x)
            hs.urlevent.openURLWithBundle("http://maps.apple.com/?q=" .. hs.http.encodeForQuery(x), "com.apple.Maps")
          end,
          keyword = "map"
        },
        -- Hammerspoon
        ["Hammerspoon Docs"] = {
          fn = function(x)
            hs.doc.hsdocs.help(x)
          end,
          keyword = "hsdocs"
        },
        ["Reload Hammerspoon"] = {
          fn = function()
            hs.reload()
          end
        },
        ["Toggle SpeedMenu"] = {
          fn = function()
            spoon.SpeedMenu:toggle()
          end
        },
        -- Web quieres
        ["Search Duck Duck Go"] = {
          url = "https://duckduckgo.com/?q=${query}",
          keyword = "ddg"
        }
      }
      x:refreshAllCommands()
    end,
    start = true,
    hotkeys = {toggle = {"cmd", "space"}}
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

    -- Hotspot specific
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

-- Submits a url to an article to text-to-speech podcast generator
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
itunesWasPlaying = false

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
    if iTunesWasPlaying then
      hs.itunes.play()
      itunesWasPlaying = false
    end
  else
    if hs.itunes.isPlaying() then
      hs.itunes.pause()
      iTunesWasPlaying = true
    end
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

----------------
-- Playground --
----------------

function defaultsWrite(domain, key, value, type)
  local output, _, _, _ = hs.execute("defaults write " .. domain .. " " .. key .. " -" .. type .. " " .. value)
  return output
end

function defaultsRead(domain, key)
  local output, _, _, _ = hs.execute("defaults read " .. domain .. " " .. key)
  return output:sub(1, -2)
end

function defaultsDelete(domain, key)
  local output, _, _, _ = hs.execute("defaults delete" .. domain .. " " .. key)
  return output
end

function toggleCaprineDarkMode()
  local caprineApp = hs.application.get("Caprine")

  if caprineApp then
    caprineApp:kill9()
  end

  local caprineConfigPath = "/Users/malo/Library/Application Support/Caprine/config.json"

  local f = io.open(caprineConfigPath, "r")
  local config = hs.json.decode(f:read("*a"))
  f:close()

  config.darkMode = not config.darkMode

  f = io.open(caprineConfigPath, "w")
  f:write(hs.json.encode(config, true))
  f:close()

  if caprineApp then
    hs.timer.doAfter(
      1,
      function()
        hs.application.open("Caprine")
      end
    )
  end
end

function toggleDarkMode()
  hs.osascript.applescript(
    [[
    tell application "System Events"
      tell appearance preferences
        set dark mode to not dark mode
   	  end tell
    end tell
    ]]
  )

  if defaultsRead("com.alexandrudenk.Dark-Mode-for-Safari.Dark-Mode", "ENABLED_FOR_ALL_SITES_KEY") == "0" then
    defaultsWrite("com.alexandrudenk.Dark-Mode-for-Safari.Dark-Mode", "ENABLED_FOR_ALL_SITES_KEY", "1", "string")
  else
    defaultsWrite("com.alexandrudenk.Dark-Mode-for-Safari.Dark-Mode", "ENABLED_FOR_ALL_SITES_KEY", "0", "string")
  end

  toggleCaprineDarkMode()
  hs.preferencesDarkMode(not hs.preferencesDarkMode())
end

function getUtcOffset()
  local utcOffset, _, _, _ = hs.execute("date +%z")
  return tonumber(utcOffset:sub(1, -4))
end

function getSunriseTime()
  hs.location.start()
  local time = hs.location.sunrise(hs.location.get(), getUtcOffset())
  hs.location.stop()
  return time
end

function getSunsetTime()
  hs.location.start()
  local time = hs.location.sunset(hs.location.get(), getUtcOffset())
  hs.location.stop()
  return time
end

hs.hotkey.bind(
  "cmd",
  "`",
  nil,
  function()
    hs.hints.windowHints(hs.window.filter.new(nil):getWindows())
  end
)
hs.hints.hintChars = {"t", "n", "s", "e", "r", "i", "a", "o", "d", "h"}
hs.hints.showTitleThresh = 10

hs.notify.show("Hammerspoon", "", "Configuration (re)loaded")

-- luacheck: allow defined top


-----------------------
-- HS initialization --
-----------------------
-- Load configuration constants used throughout the code
consts = require "configConsts"

-- Reload Hammerspoon on changes in config dir
-- reloadConfWatcher = hs.pathwatcher.new(hs.configdir, hs.reload):start() -- luacheck: ignore

-- Other misc initialization/config
hyper = { "ctrl", "alt", "cmd" } -- Modifier combo for later use
hs.doc.hsdocs.forceExternalBrowser(true)


-------------------
-- Spoons config --
-------------------
-- SpoonInstall, to manage installation and setup of all other spoons
-- http://www.hammerspoon.org/Spoons/SpoonInstall.html
local spoonInstall = hs.loadSpoon("SpoonInstall")

-- DarkMode, enable/disable DarkMode on a schedule
-- https://github.com/malob/DarkMode.spoon
-- spoonInstall:andUse(
--   "DarkMode",
--   {
--     config = {
--       lightAutoToggle = { enabled = true }
--     },
--     start = false
--   }
-- )

-- Asana, creates a new task in Asana with a given name in a given workspace
-- https://github.com/malob/Asana.Spoon
spoonInstall:andUse("Asana", { config = { apiKey = consts.asanaApiKey } })

-- KSheet, keyboard shortcuts popup window
-- http://www.hammerspoon.org/Spoons/KSheet.html
spoon.SpoonInstall:andUse("KSheet")
local ksheetVisible = false
local function toggleKSheet()
  if ksheetVisible then
    spoon.KSheet:hide()
    ksheetVisible = false
  else
    spoon.KSheet:show()
    ksheetVisible = true
  end
end
hs.hotkey.bind(hyper, "/", toggleKSheet)

-- PersonalHotspot, connect/disconnect a personal hotspoot
-- https://github.com/malob/PersonalHotspot.spoon
spoonInstall:andUse(
  "PersonalHotspot",
  {
    config = {
      hotspotName = consts.hotspots[1],
      appsToKill = consts.highBandwidthApps
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
      url_patterns    = consts.urlPatterns
    },
    start = true
  }
)

-- USBDeviceActions, opens/closes apps or runs an arbitrary function when a USB device is connected/disconnected
-- https://github.com/malob/USBDevices.spoon
function toggleKeyboardLayout(x)
  if x then hs.keycodes.setLayout("U.S.") else hs.keycodes.setLayout("Colemak") end
end
spoonInstall:andUse(
  "USBDeviceActions",
  {
    config = {
      devices = {
        ScanSnapiX500EE            = { apps = { "ScanSnap Manager Evernote Edition" } },
        Planck                     = { fn = toggleKeyboardLayout },
        ["Corne Keyboard (crkbd)"] = { fn = toggleKeyboardLayout }
      }
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
      x:loadPlugins({"apps", "calc", "useractions", "rot13", "safari_tabs", "onetimesecret"})
      x.plugins.onetimesecret.apiCredentials = {
        user = consts.onetimesecretUser,
        key  = consts.onetimesecretKey,
      }
      x.plugins.useractions.actions = {

        -- Asana
        ["New Asana task in " .. consts.asanaWorkWorkspaceName] = {
          fn      = function(y) spoon.Asana:createTask(y, consts.asanaWorkWorkspaceName) end,
          keyword = "awork"
        },
        ["New Asana task in " .. consts.asanaPersonalWorkspaceName] = {
          fn      = function(y) spoon.Asana:createTask(y, consts.asanaPersonalWorkspaceName) end,
          keyword = "ahome"
        },

        -- Audio devices commands
        ["Connect AirPods"]    = { fn = function() changeAudioDevice("Malo’s AirPods") end },
        ["Connect Beats"]      = { fn = function() changeAudioDevice("Malo’s Beats Studio³") end },
        ["Connect LG Display"] = { fn = function() changeAudioDevice("LG UltraFine Display Audio") end },
        ["Connect Built-in"]   = {
          fn = function()
            hs.audiodevice.findInputByName("Built-in Microphone"):setDefaultInputDevice()
            hs.audiodevice.findOutputByName("Built-in Output"):setDefaultOutputDevice()
            hs.notify.show("Audio Device", "", "Built-in connected")
          end
        },

        -- Hammerspoon
        ["Hammerspoon Docs"]   = { fn = function(y) hs.doc.hsdocs.help(y) end, keyword = "hsdocs" },
        ["Reload Hammerspoon"] = { fn = function() hs.reload() end },

        -- Power commands
        ["Lock"]           = { fn = function() hs.eventtap.keyStroke({ "cmd", "ctrl" }, "q") end },
        ["Restart/Reboot"] = { fn = function() hs.caffeinate.restartSystem() end },
        ["Shutdown"]       = { fn = function() hs.caffeinate.shutdownSystem() end },

        -- Text-to-speech commands
        ["Add article to TTS podcast"] = { fn = function(y) ttsPodcast(y) end, keyword = "ttspod" },
        ["Pause/Play TTS"]             = { fn = function() pauseOrContinueTts() end },
        ["Speak text"]                 = { fn = function(y) speakText(y) end, keyword = "speak" },

        -- Other commands
        ["Toggle hotspot"] = { fn = function() spoon.PersonalHotspot:toggle() end },
        ["Make a phone call"] = {
          fn = function(y) hs.urlevent.openURL("tel://" .. hs.http.encodeForQuery(y)) end,
          keyword = "call"
        },
        ["Rotate Display"] = {
          fn = function(y)
            local screen = hs.screen.primaryScreen()
            return screen:rotate() == 0 and screen:rotate(90) or screen:rotate(0)
          end
        },
        ["Search in Maps"] = {
          fn = function(y)
            hs.urlevent.openURLWithBundle("http://maps.apple.com/?q=" .. hs.http.encodeForQuery(y), "com.apple.Maps")
          end,
          keyword = "map"
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
    hotkeys = { toggle = { "cmd", "space" } }
  }
)


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


----------------------------
-- Text-to-speech podcast --
----------------------------

-- Submits a url to an article to text-to-speech podcast generator
-- If url is nil as an argument then uses whatever text is currently selected
-- See https://github.com/malob/serverless-tts-podcast for info on the rest of the service
function ttsHttpPost(data, url)
  hs.notify.show("TTS Podcast", "", "Adding new content")
  local postData = { ["messages"] = { { ["data"] = data } } }
  hs.http.asyncPost(
    url,
    hs.json.encode(postData, true),
    {["Content-Type"] = "application/json"},
    function(code, response)
      if code == 200 then
        hs.notify.show("TTS Podcast", "", "Content received successfully!")
      else
        hs.notify.show("TTS Podcast", "", "Error sending content!")
        print(response)
        hs.toggleConsole()
      end
    end
  )
end

function ttsPodcast(url)
  if not url then
    hs.eventtap.keyStroke({ "cmd" }, "c")
    url = hs.pasteboard.readString()
  end
  ttsHttpPost(hs.base64.encode(url), consts.ttsPodcastArticleUrl)
end
hs.hotkey.bind({ "cmd", "shift" }, "escape", ttsPodcast)

function ttsPodcastCustom()
  local content   = hs.pasteboard.readString()
  local _, title  = hs.dialog.textPrompt("Enter Title", "")
  local _, author = hs.dialog.textPrompt("Enter Author", "")
  local _, date   = hs.dialog.textPrompt("Enter Publication Date", "")
  local _, url    = hs.dialog.textPrompt("Enter URL", "")

  local data = {
    ["title"]          = title,
    ["author"]         = author,
    ["date_published"] = date,
    ["url"]            = url,
    ["content"]        = content
  }

  ttsHttpPost(hs.base64.encode(hs.json.encode(data, true)), consts.ttsPodcastDataUrl)
end

hs.hotkey.bind({ "cmd", "shift", "control" }, "escape", ttsPodcastCustom)


--------------------------
-- macOS text-to-speech --
--------------------------

ttsSynth = hs.speech.new(consts.osTtsVoice)
ttsSynth:rate(consts.osTtsRate)
iTunesWasPlaying = false

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
    hs.eventtap.keyStroke({ "cmd" }, "c")
    textToSpeak = hs.pasteboard.readString()
  end
  if ttsSynth:isSpeaking() then
    ttsSynth:stop()
    if iTunesWasPlaying then
      hs.itunes.play()
      iTunesWasPlaying = false
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
hs.hotkey.bind({ "option", "shift" }, "escape", pauseOrContinueTts)


------------------
-- VPN and WiFi --
------------------

-- Watches for SSID change
-- If network isn't trusted loads VPN application
-- If network is a hotspot kills high-bandwidth apps
function wifiChange(_, message, interface)
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
  end
end

hs.wifi.watcher.new(wifiChange):start()


-----------------
-- Other stuff --
-----------------

-- Hints setup
hs.hotkey.bind(hyper, "`", nil, hs.hints.windowHints)
hs.hints.hintChars = {"t", "n", "s", "e", "r", "i", "a", "o", "d", "h"}
hs.hints.showTitleThresh = 0
hs.window.animationDuration = 0.1

-- Send notification that config has been (re)loaded
hs.notify.show("Hammerspoon", "", "Configuration (re)loaded")

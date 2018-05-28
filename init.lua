-----------------------
-- HS initialization --
-----------------------

-- Load constants
consts = require "configConsts"

-- Load spoons
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall:andUse("KSheet")
spoon.SpoonInstall:andUse("SpeedMenu")
spoon.SpoonInstall:andUse("URLDispatcher")

-- Reload HS on changes in config dir
hs.pathwatcher.new(hs.configdir, hs.reload):start()

---------------------------
-- URL Dispatcher config --
---------------------------
-- http://www.hammerspoon.org/Spoons/URLDispatcher.html
spoon.URLDispatcher.url_patterns = consts.urlPatterns
spoon.URLDispatcher:start()

------------------
-- VPN and WiFi --
------------------
function wifiChange(watcher, message, interface)
  if message == "SSIDChange" then
    local ssid = hs.wifi.currentNetwork(interface)

    -- Connect/disconnect from VPN
    if hs.fnutils.contains(hs.fnutils.concat(consts.trustedNetworks, consts.hotspots), ssid) then
      hs.application.get("ProtonVPN"):kill()
    else
      hs.application.open("ProtonVPN")
    end

    -- Hotspot specifc
    if hs.fnutils.contains(consts.hotspots, ssid) then
      hs.fnutils.ieach(
        consts.highBandwidthApps,
        function(x)
          hs.application.get(x):kill()
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

-----------------
-- TTS Podcast --
-----------------
function ttsPodcast()
  hs.notify.show("TTS Podcast", "Adding new article")
  local data = {["url"] = hs.pasteboard.readString()}
  hs.http.asyncPost(
    consts.ttsPodcastUrl,
    hs.json.encode(data, true),
    {["Content-Type"] = "application/json"},
    function(code, response, headers)
      if code == 200 then
        hs.notify("TTS Podcast", "Article added successfully!")
      else
        hs.notify("TTS Podcast", "Error adding article!")
      end
      print(response)
    end
  )
end

hs.hotkey.bind({"cmd", "shift"}, hs.keycodes.map["escape"], ttsPodcast)

---------------
-- macOS TTS --
---------------
ttsSynth = hs.speech.new(consts.osTtsVoice)
ttsSynth:rate(consts.osTtsRate)

function pauseOrContinueTTS()
  if ttsSynth:isPaused() then
    ttsSynth:continue()
  else
    ttsSynth:pause()
  end
end

function speakSelectedText()
  if ttsSynth:isSpeaking() then
    ttsSynth:stop()
  else
    hs.eventtap.keyStroke({"cmd"}, "c")
    ttsSynth:speak(hs.pasteboard.readString())
  end
end

hs.hotkey.bind({"option"}, hs.keycodes.map["escape"], speakSelectedText)
hs.hotkey.bind({"option", "shift"}, hs.keycodes.map["escape"], pauseOrContinueTTS)

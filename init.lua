------------------
-- VPN and WiFi --
------------------
trustedNetworks = {"MIRICFAR UniFi", "Gerlo"}
hotspots = {"Malo’s iPhone", "Malo’s iPad"}
highBandwidthApps = {"Arq", "Arq Agent", "Google Drive File Stream"}

function wifiChange(watcher, message, interface)
  if message == "SSIDChange" then
    local network = hs.wifi.currentNetwork(interface)

    -- Connect/disconnect from VPN
    if not network or hs.fnutils.contains(hs.fnutils.concat(trustedNetworks, hotspots), network) then
      hs.application.get("ProtonVPN"):kill()
    else
      hs.application.open("ProtonVPN")
    end

    -- Hotspot specifc
    if hs.fnutils.contains(hotspots, network) then
      hs.fnutils.ieach(highBandwidthApps, function(x) hs.application.get(x):kill() end)
    else
      hs.fnutils.ieach(highBandwidthApps, function(x) hs.application.open(x) end)
    end
  end
end

local wifiWatcher = hs.wifi.watcher.new(wifiChange):start()

-------------------
-- Screen change --
-------------------
function screenChange()
  local screens = hs.screen.allScreens()

  local modsPressed = hs.eventtap.checkKeyboardModifiers()
end

-- local screenWatcher = hs.screen.watcher.new(screenChange):start()

--------------------
-- Text-to-speech --
--------------------
function copySelected()
  hs.eventtap.event.newKeyEvent({"cmd"}, "c", true):post()
  hs.eventtap.event.newKeyEvent({"cmd"}, "c", false):post()
end

function getGcpAuthToken()
  local authToken = ""
  hs.task.new("/usr/local/bin/gcloud", function(_, stdOut, _) authToken = stdOut end, {"auth", "application-default", "print-access-token"}):start():waitUntilExit()
  return string.gsub(authToken, "\n", "")
end

function cleanText(text)
  text = string.gsub(text, "‘", "'")
  text = string.gsub(text, "’", "'")
  text = string.gsub(text, "“", '"')
  text = string.gsub(text, "”", '"')
  text = string.gsub(text, " — ", ", ")
  text = string.gsub(text, "—", ", ")
  text = string.gsub(text, "–", ", ")
  text = string.gsub(text, "\n", ", ")
  return text
end

function generateSpeechAudio(text)
  -- Setup http request variables
  local url = "https://texttospeech.googleapis.com/v1beta1/text:synthesize"

  local data = {
    ["input"] = {
      ["text"] = text
    },
    ["voice"] = {
      ["languageCode"] = "en-US",
      ["name"] = "en-US-Wavenet-C",
      ["ssmlGender"] = "FEMALE"
    },
    ["audioConfig"] = {
      ["audioEncoding"] = "MP3",
      ["speakingRate"] = 1
    }
  }

  local headers = {
    ["Authorization"] = "Bearer " .. getGcpAuthToken(),
    ["Content-Type"] = "application/json; charset=utf-8"
  }

  -- Execute request
  local code, response, _ = hs.http.post(url, hs.json.encode(data, true), headers)
  if code == 200 then print("GCP request successful") else print(response) end

  -- Extract and return mp3 data
  return hs.base64.decode(hs.json.decode(response)["audioContent"])
end

function writeMp3Files(mp3Data)
  local mp3FilePath = "/tmp/" .. hs.hash.MD5(mp3Data) .. ".mp3"
  local mp3File = io.open(mp3FilePath, "w+")

  mp3File:write(mp3Data)
  mp3File:close()
  return mp3FilePath
end

function textToSpeech()
  -- Copy selected text and retrive from pasteboard
  print("Getting text")
  -- copySelected()
  local textToSpeak = cleanText(hs.pasteboard.readString())

  -- Divide up text to deal with GCP char limit
  local gcpCharLimit = 5000
  print("Dividing text up into " .. textToSpeak:len()//gcpCharLimit + 1 .. " sections")
  local textSections = {}
  for i = 1, textToSpeak:len(), gcpCharLimit do
    table.insert(textSections, textToSpeak:sub(i, i + gcpCharLimit -1))
  end

  -- Generate mp3 data from text and write to file
  print("Retreiving mp3 data from GCP")
  local mp3Data = hs.fnutils.imap(textSections, generateSpeechAudio)
  print("mp3 data retrieved")

  print("Writing files to disk")
  local mp3FilePaths = hs.fnutils.imap(mp3Data, writeMp3Files)

  -- Play file in VLC
  print("Opening files in VLC")
  mp3FilePaths = hs.fnutils.imap(mp3FilePaths, function(x) return "file://" .. x end)
  hs.task.new("/usr/local/bin/vlc", nil, hs.fnutils.concat({"--rate=2.0"}, mp3FilePaths)):start()
end

-- Hotkey for text-to-speech
local textToSpeechHk = hs.hotkey.bind({"cmd", "shift"}, hs.keycodes.map["escape"], textToSpeech, nil, nil)

----------
-- Misc --
----------
local hsConfigWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.config/hammerspoon/", hs.reload):start()

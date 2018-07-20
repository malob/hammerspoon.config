return {
  ----------------------
  -- WiFi/VPN related --
  ----------------------
  -- Trusted wifi network ssids, used to decide whether to connect VPN or not
  trustedNetworks = {"MIRICFAR UniFi", "Gerlo"},
  -- Network ssids for hotspots, first one used when toggling thethering with Seal
  hotspots = {"Malo’s iPhone", "Malo’s iPad"}, -- First eme
  -- Apps to kill when connecting to hotspot
  highBandwidthApps = {"Arq", "Arq Agent", "Google Drive File Stream"},
  -- VPN client name, for best results should be set to auto-connect on launch
  vpnApp = "ProtonVPN",
  -- Patterns for use with URLDispatcher http://www.hammerspoon.org/Spoons/URLDispatcher.html
  defaultUrlHandler = "com.apple.Safari",
  urlPatterns = {
    {"https?://meet.google.com", "com.google.Chrome"}
  },
  --------------------
  -- Text-to-speech --
  --------------------
  -- OS text-to-speech related
  osTtsVoice = "samantha.premium",
  osTtsRate = 300, -- words per minute
  -- URL to cloud function to add new article to personal text-to-speech podcast
  -- https://github.com/malob/article-to-audio-cloud-function
  ttsPodcastUrl = "",
  -----------
  -- Asana --
  -----------
  -- Asana API key
  -- Generated in My Profile Settings -> Apps -> Manage Developer Apps -> Create New Personal Access Token
  asanaApiKey = "",
  -- Names for Asana workspaces used for work and personal
  asanaWorkWorkspaceName = "MIRI",
  asanaPersonalWorkspaceName = "Gerlo"
}

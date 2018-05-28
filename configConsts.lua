return {
  -- WiFi/VPN related
  trustedNetworks = {"MIRICFAR UniFi", "Gerlo"},
  hotspots = {"Malo’s iPhone", "Malo’s iPad"},
  highBandwidthApps = {"Arq", "Arq Agent", "Google Drive File Stream"},
  -- URLDispatcher
  urlPatterns = {
    {".*meet%.google%.com.*", "com.google.Chrome"}
  },
  -- TTS
  osTtsVoice = "samantha.premium",
  osTtsRate = 300, -- words per minute
  ttsPodcastUrl = nil
}
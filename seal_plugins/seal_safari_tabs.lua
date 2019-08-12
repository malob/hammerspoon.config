--TODO: Remove duplicates (almost always pinned tabs)
local obj   = {}
obj.__index = obj
obj.__name  = "seal_safari_tabs"

local choicesCache = {}

local function getTabs()
  local _, tabData = hs.osascript.javascript(
    [[
    const tabData = []

    const safariWindows = Application("Safari").windows()
      .forEach(function(window) {
        window.tabs().forEach(function(tab) {
        tabData.push({
          windowId: window.id(),
          index: tab.index(),
          name: tab.name(),
          url: tab.url()
        })
      })
    })

    tabData
    ]]
  )
  return tabData;
end

local function focusTab(windowId, tabIndex)
  local script = string.format(
    [[
    const safari = Application("Safari")
    const window = safari.windows.byId(%i)
    window.currentTab = window.tabs.at(%i-1)
    window.activate
    window.visible = true
    window.index = 1
    safari.activate()
    ]],
    windowId,
    tabIndex
  )
  hs.osascript.javascript(script)
end

function obj:commands()
  return {
    stab = {
      cmd         = "stab",
      fn          = obj.choicesTabs,
      name        = "Safari Tabs",
      description = "List and focus Safari tabs",
      plugin      = obj.__name
    }
  }
end

function obj:bare()
   return nil
end

function obj.choicesTabs(query)
  if not query or query == "" then
    choicesCache = {}
    hs.fnutils.each(getTabs(), function(x)
      table.insert(choicesCache, {
        text     = x.name,
        subText  = x.url,
        windowId = x.windowId,
        tabIndex = x.index,
        plugin   = obj.__name,
      })
    end)
  end

  return choicesCache
end

function obj.completionCallback(rowInfo)
  focusTab(rowInfo.windowId, rowInfo.tabIndex)
end

return obj

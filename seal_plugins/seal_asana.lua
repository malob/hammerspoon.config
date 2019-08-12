-- TODO: incomplete, need to integrate with Asana spoon
local asana = require("Asana")

local obj = {}
obj.__index = obj
obj.__name = "seal_asana"
obj.workspace = ""

function obj:commands()
  return {
    asanaAdd = {
      cmd = "asana a",
      fn = nil,
      name = "Asana",
      description = "Add task to " .. self.workspace .. " workspace"
    },
    asanaWorkspace = {
      cmd = "asana w",
      fn = nil,
      name = "Asana",
      description = "List Asana workspaces"
    }
  }
end

function obj:bare()
  return nil
end

function obj.completionCallback(rowInfo)
  if rowInfo["type"] == "copyToClipboard" then
    hs.pasteboard.setContents(rowInfo["text"])
  end
end

return obj

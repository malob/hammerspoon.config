local obj   = {}
obj.__index = obj
obj.__name  = "seal_onetimesecret"

-- One-Time Secret settings
obj.apiCredentials   = {}
obj.secretTtl        = 604800 -- seconds until secret expires (7 days)
obj.secretPassphrase = "" -- passphare used when creating secret, empty string indicates not passphrase

local otsImage = hs.image.imageFromPath(hs.configdir .. "/seal_plugins/onetimesecret_icon.png")

function obj:commands()
  return {
    ots = {
      cmd         = "ots",
      fn          = self.parseSubCmds,
      name        = "One-Time Secret",
      description = "Create a new One-Time Secret"
    }
  }
end

function obj:bare()
  return nil
end

function obj.createSecret(query)
  return {
    {
      text    = query,
      subText = "Copy OTS link to the clipboard",
      plugin  = obj.__name,
      image   = otsImage,
      type    = "addSecretUrlToClipboard"
    }
  }
end

function obj.changeTtl(query)
  local choice = {
    plugin = obj.__name,
    image  = otsImage
  }

  if tonumber(query) == nil and query ~= "" then
    choice.text    = "Error"
    choice.subText = "Input is not a number"
    return {choice}
  end

  if query == "" then
    choice.text    = tostring(obj.secretTtl)
    choice.subText = "Current TTL is "
  else
    choice.text    = tostring(tonumber(query))
    choice.subText = "Change TTL to "
    choice.type    = "changeSecretTtl"
  end

  choice.subText =
    choice.subText ..
      choice.text / 60 .. " minutes or " .. choice.text / 60 / 60 .. " hours or " .. choice.text / 60 / 60 / 24 .. " days"
  return {choice}
end

function obj.changePassphrase(query)
  local choice = {
    plugin = obj.__name,
    image  = hs.image.imageFromPath(obj.seal.spoonPath .. "/onetimesecret_icon.png")
  }

  if query == "" then
    if obj.secretPassphrase == "" then
      choice.text    = ""
      choice.subText = "You don't currently have a passphare set"
    else
      choice.text    = obj.secretPassphrase
      choice.subText = "This is your passphrase, hit enter to copy it"
      choice.type    = "copyToClipboard"
    end
  else
    choice.text    = query
    choice.subText = "Set new passphare"
    choice.type    = "changePassphrase"
  end

  return {choice}
end

function obj.completionCallback(choice)
  local baseUrl = "https://onetimesecret.com/api/v1/"

  if choice.type == "addSecretUrlToClipboard" then
    local data = "secret=" .. hs.http.encodeForQuery(choice.text) .. "&ttl=" .. obj.secretTtl
    if obj.secretPassphrase ~= "" then
      data = data .. "&passphrase=" .. hs.http.encodeForQuery(obj.secretPassphrase)
    end
    local headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Authentication"] = "Basic" .. hs.base64.encode(obj.apiCredentials.user .. ":" .. obj.apiCredentials.key)
    }
    hs.http.asyncPost(
      baseUrl .. "share",
      data,
      headers,
      function(status, res)
        if status == 200 then
          res = hs.json.decode(res)
          hs.pasteboard.setContents("https://onetimesecret.com/secret/" .. res.secret_key)
          hs.notify.show("One-Time Secret", "", "OTS secret link added to clipboard")
        else
          print(hs.inspect(res))
        end
      end
    )
  elseif choice.type == "changeSecretTtl" then
    obj.secretTtl = choice.text
  elseif choice.type == "changePassphrase" then
    obj.secretPassphrase = choice.text
  elseif choice.type == "copyToClipboard" then
    hs.pasteboard.setContents(choice.text)
  end
end

obj.subCmdsChoices = {
  {
    text    = "new",
    subText = "Create new One-Time Secret",
    image   = otsImage
  },
  {
    text    = "ttl",
    subText = "View or change the expiry time of One-Time Secrets",
    image   = otsImage
  },
  {
    text    = "pass",
    subText = "View or change passphrase used to encrypt One-Time Secrets",
    image   = otsImage
  }
}

obj.subCmdsFns = {
  new  = obj.createSecret,
  ttl  = obj.changeTtl,
  pass = obj.changePassphrase
}

function obj.parseSubCmds(query)
  local cmd, subQuery = string.match(query, "^(%a+) ?(.*)")

  local choices = hs.fnutils.imap(
    obj.subCmdsChoices,
    function(choice)
      if choice.text == cmd then
        return obj.subCmdsFns[cmd](subQuery)
      elseif query == "" or string.match(choice.text, "^" .. cmd) then
        return {choice}
      else
        return {}
      end
    end
  )

  return hs.fnutils.reduce(choices, hs.fnutils.concat)
end

return obj

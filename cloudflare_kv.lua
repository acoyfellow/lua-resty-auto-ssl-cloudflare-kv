local http = require "resty.http"
local cjson = require "cjson"

local _M = {}

function _M.new(auto_ssl_instance)
  local options = auto_ssl_instance:get("cloudflare_kv") or {}
  assert(
    options.account_id 
    and options.namespace_id 
    and options.api_key 
    and options.account_email, 
    "Cloudflare KV configuration is incomplete"
  )
  return setmetatable({
    options = options,
    kv_url = string.format(
      "https://api.cloudflare.com/client/v4/accounts/%s/storage/kv/namespaces/%s", 
      options.account_id, 
      options.namespace_id
    )
  }, { __index = _M })
end

-- Updated kv_request function with TTL support for PUT requests
local function kv_request(self, method, path, body, ttl)
  ngx.log(ngx.INFO, "auto-ssl: Cloudflare_KV request: ", self.kv_url .. path)
  local httpc = http.new()
  local headers = {
    ["Content-Type"] = "application/json",
    ["X-Auth-Key"] = self.options.api_key,
    ["X-Auth-Email"] = self.options.account_email,
  }

  local body_data = body and cjson.encode(body) or nil
  -- If TTL is provided and method is PUT, add expiration_ttl to the body
  if ttl and method == "PUT" and type(body) == "table" then
    body["expiration_ttl"] = ttl
    body_data = cjson.encode(body)
  end

  local res, err = httpc:request_uri(self.kv_url .. path, {
    method = method,
    body = body_data,
    headers = headers,
  })

  if not res then
    return nil, "Failed request: " .. err
  elseif res.status >= 400 then
    return nil, "KV error: " .. res.body
  else
    return cjson.decode(res.body), nil
  end
end

function _M.get(self, key)
  local result, err = kv_request(self, "GET", "/values/" .. ngx.escape_uri(key))
  if err then
    ngx.log(ngx.ERR, "auto-ssl: Cloudflare_KV get() error ("..ngx.escape_uri(key)..")", err)
    return nil, err
  end
  if result and result.value then
    return result.value
  else
    return nil, "Key not found."
  end

end

function _M.set(self, key, value, options)
  local ttl = options and options["exptime"] or nil
  local result, err = kv_request(self, "PUT", "/values/" .. ngx.escape_uri(key), {value = value}, ttl)
  if err then
    ngx.log(ngx.ERR, "auto-ssl: Cloudflare_KV set() error ("..ngx.escape_uri(key)..")", err)
    return false, err
  end

  -- Optional: Check response to ensure value was successfully set
  -- This step depends on Cloudflare KV's response format and may need adjustment
  if result and result.success then
    return true
  else
    -- Log specific error if result indicates failure
    ngx.log(ngx.ERR, "auto-ssl: Cloudflare_KV set() failed for key: ", key, "; Response: ", result)
    return false, "Failed to set value in Cloudflare KV"
  end
end

function _M.delete(self, key)
  local _, err = kv_request(self, "DELETE", "/values/" .. ngx.escape_uri(key))
  if err then
    ngx.log(ngx.ERR, "auto-ssl: Cloudflare_KV delete() error ("..ngx.escape_uri(key)..")", err)
    return false, err
  end
  return true
end

function _M.keys_with_suffix(self, suffix)
  local keys = {}
  local cursor = nil
  repeat
    local url = "/keys"
    if cursor then
      -- When there's a cursor, append it to the URL for pagination
      url = url .. "?cursor=" .. cursor
    end
    -- Perform the KV request. The 'kv_request' function needs to handle HTTP specifics, including setting the correct headers and interpreting the response.
    local result, err = kv_request(self, "GET", url)
    if err then
      ngx.log(ngx.ERR, "auto-ssl: Cloudflare KV list keys error: ", err)
      return nil, err
    end

    -- Process the keys, filtering by the specified suffix
    for _, key_info in ipairs(result.result) do
      if string.sub(key_info.name, -#suffix) == suffix then
        table.insert(keys, key_info.name)
      end
    end
    -- Update the cursor for pagination. If there are no more pages, Cloudflare's API sets this to an empty string.
    cursor = result.result_info.cursor
  until cursor == "" -- Continue until there's no more cursor indicating more pages of results
  
  return keys
end



return _M

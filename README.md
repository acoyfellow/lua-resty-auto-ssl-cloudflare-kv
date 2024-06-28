# lua-resty-auto-ssl-cloudflare-kv

A Cloudflare KV storage adapter for [lua-resty-auto-ssl](https://github.com/auto-ssl/lua-resty-auto-ssl), enabling the use of Cloudflare's key-value storage for persisting SSL certificates. This adapter facilitates seamless integration with Cloudflare's KV storage API, providing a reliable and scalable solution for SSL certificate storage in OpenResty applications.

## Features

- Store SSL certificates in Cloudflare's key-value storage.
- Retrieve, set, and delete SSL certificate keys with ease.
- Supports setting TTL (time-to-live) for stored keys.
- Pagination support for listing keys with a specific suffix.

## Requirements

- OpenResty with `lua-resty-http` and `lua-cjson` modules installed.
- A Cloudflare account with KV storage enabled.
- Cloudflare API credentials (Account ID, Namespace ID, API Key, and Account Email).

## Installation

1. **Install dependencies:**

   Make sure you have `lua-resty-http` and `lua-cjson` installed in your OpenResty setup.

2. **Clone the repository:**

   ```sh
   git clone https://github.com/acoyfellow/lua-resty-auto-ssl-cloudflare-kv.git
   ```
   
 3. **Add the adapter to your lua_package_path:**
    
    In your nginx.conf, add the path to the cloned repository:
    ```nginx
    http {
    lua_package_path "/path/to/lua-resty-auto-ssl-cloudflare-kv/?.lua;;";
        ...
    }
    ```

## Configuration

1. **Configure lua-resty-auto-ssl:**

   In your `nginx.conf` or a separate Lua configuration file, configure lua-resty-auto-ssl to use the Cloudflare KV storage adapter:

   ```lua
   local auto_ssl = (require "resty.auto-ssl").new()

   auto_ssl:set("cloudflare_kv", {
       account_id = "your_account_id",
       namespace_id = "your_namespace_id",
       api_key = "your_api_key",
       account_email = "your_account_email",
   })
   auto_ssl:set("storage_adapter", "path.to.cloudflare_kv_adapter")
   ```
   
2. **Initialize auto-ssl:**
    
    In your nginx.conf, initialize auto-ssl:
    ```
    init_by_lua_block {
        auto_ssl:init()
    }

    init_worker_by_lua_block {
        auto_ssl:init_worker()
    }

    server {
        listen 443 ssl;
        server_name example.com;

        ssl_certificate_by_lua_block {
            auto_ssl:ssl_certificate()
        }

        location / {
            proxy_pass http://your_backend;
        }
    }
    ```
## Usage

The Cloudflare KV adapter provides methods for storing, retrieving, and deleting SSL certificate keys:

- `get(self, key)`: Retrieves the value for the given key.
- `set(self, key, value, options)`: Sets the value for the given key with optional TTL.
- `delete(self, key)`: Deletes the given key.
- `keys_with_suffix(self, suffix)`: Lists keys with the specified suffix.

### Example

Here's a simple example of using the Cloudflare KV storage adapter:

```lua
local cloudflare_kv = require "path.to.cloudflare_kv_adapter"

local storage = cloudflare_kv.new({
    account_id = "your_account_id",
    namespace_id = "your_namespace_id",
    api_key = "your_api_key",
    account_email = "your_account_email",
})

-- Set a key
local success, err = storage:set("example_key", "example_value", { exptime = 3600 })
if not success then
    ngx.log(ngx.ERR, "Failed to set key: ", err)
end

-- Get a key
local value, err = storage:get("example_key")
if err then
    ngx.log(ngx.ERR, "Failed to get key: ", err)
else
    ngx.say("Value: ", value)
end

-- Delete a key
local success, err = storage:delete("example_key")
if not success then
    ngx.log(ngx.ERR, "Failed to delete key: ", err)
end

-- List keys with suffix
local keys, err = storage:keys_with_suffix("_suffix")
if err then
    ngx.log(ngx.ERR, "Failed to list keys: ", err)
else
    for _, key in ipairs(keys) do
        ngx.say("Key: ", key)
    end
end
```

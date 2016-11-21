-- Imports required libraries
local cjson = require "cjson"
local redis = require "resty.redis"

-- Redis API client
local red = redis:new()
red:set_timeout(1000) -- 1 sec to connect to redis
-- request headers
local headers = ngx.req.get_headers()
-- gets the url params
local args = ngx.req.get_uri_args()
-- Getting api token, it can bein the header or as param in the URL
local token
if args then
    token = args['token']
end
if token == nil and headers then
    token = headers["X-AUTH-TOKEN"]
end
local client_key
if token then
    client_key = 'has_requests_log_enabled:' .. token
end
-- Connect to redis
local ok, err = red:connect("127.0.0.1", 6379)
--required to load request body
ngx.req.read_body()
-- post body as table
local post_args = ngx.req.get_post_args()
-- get request body as string
local body = ngx.req.get_body_data()
-- table of methods
local methods = {
    GET = ngx.HTTP_GET,
    POST = ngx.HTTP_POST,
    PUT = ngx.HTTP_PUT,
    HEAD = ngx.HTTP_HEAD,
    DELETE = ngx.HTTP_DELETE,
    OPTIONS = ngx.HTTP_OPTIONS,
    PATCH = ngx.HTTP_PATCH
}
-- Gets request method as string
local method = ngx.req.get_method()
-- Options that will be sent to the API
local redirect_options = {}
if body then
    redirect_options['body'] = body
end
if post_args then
    redirect_options['args'] = post_args
end
if method then
    redirect_options['method'] = methods[method]
end
-- gets the URI requested by the client
local uri = ngx.var.request_uri
-- The server will make a subrequest from /api/v1.6... to /local_api/v1.6...
local redirect_uri = '/local_api' .. uri:sub(5)
-- Making subrequest to another location
local res = ngx.location.capture(redirect_uri, redirect_options)
-- Gets the headers of the response
local response_headers = res.header
-- Update response headers  according to the result of the subrequest
for k, v in pairs(response_headers) do
    ngx.header[k] = v
end
-- Getting UTC timestamp in the format YYYY-MM-DD HH:mm:ss
local response_time = ngx.utctime()
response_headers['date'] = response_time
-- Create a JSON Document with the information of the request and response received by the API
-- The document will be created only if the client with the token activated logs
if client_key and red:get(client_key) == "true" and res then
    local request = { body = body, headers = headers, url = uri, method = method, post_args = post_args, query_params = args }
    local response = { body = res.body, headers = response_headers, status = res.status }
    local json = cjson.encode({ request = request, response = response })
    -- Request information is published to redis channel for the client with specified token
    if token then
        -- Redis PUB/SUB does not care about the database, any subscriber with any database selected will
        -- receive the published message
        ok, err = red:publish("client_requests_log:" .. token, json)
    end
end
if res then
    -- updates response status
    ngx.status = res.status
    -- prints subrequest body
    ngx.print(res.body)
end
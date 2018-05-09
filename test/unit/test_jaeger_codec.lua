local jaeger_codec = require "kong.plugins.zipkin.jaeger_codec"

local lu = require("luaunit")

TestJaegerCodec = require("test.unit.base_case"):extend()

function TestJaegerCodec:setUp()

  TestJaegerCodec.super:setUp()
  self.logs = {}
  self.mocked_ngx = {
    DEBUG = "debug",
    ERR = "error",
    HTTP_UNAUTHORIZED = 401,
    ctx = {},
    header = {},
    var = {request_uri = "/"},
    req = {
      get_uri_args = function(...) end,
      set_header = function(...) end,
      get_headers = function(...) end
    },
    log = function(...)
      self.logs[#self.logs+1] = table.concat({...}, " ")
      print("ngx.log: ", self.logs[#self.logs])
    end
  }
  self.ngx = _G.ngx
  _G.ngx = self.mocked_ngx

end

function TestJaegerCodec:tearDown()
  TestJaegerCodec.super:tearDown()
   _G.ngx = self.ngx
end



function TestJaegerCodec:testBasic()

  local function warn(str)
    print(str)
  end
  headers = {}
  headers["uber-trace-id"] = "bad_test_value"
  extractor = jaeger_codec.new_extractor(warn)(headers)


  print(extractor)

  -- lu.assertEquals(ex.validate_user_trace_id(), true)
end

lu.run()

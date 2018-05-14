local to_hex = require "resty.string".to_hex
local new_span_context = require "opentracing.span_context".new

local function hex_to_char(c)
	return string.char(tonumber(c, 16))
end

local function from_hex(str)
	if str ~= nil then -- allow nil to pass through
		str = str:gsub("%x%x", hex_to_char)
	end
	return str
end

local function new_extractor(warn)
	return function(headers)

		local had_invalid_id = false

		local trace_id = headers["uber-trace-id"]

		local function validate_trace_id()
			return true
		end
		local function validate_span_id()
			return true
		end
		local function validate_parent_span_id()
			return true
		end
		local function validate_flags()
			return true
		end


		local function validate_user_trace_id(trace_id, validate_trace_id_function, validate_span_id_function, validate_parent_span_id_function, validate_flags_function)
			-- add validation here
			sep = ":"
			trace_id = trace_id .. sep
			splitted = {trace_id:match((trace_id:gsub("[^"..sep.."]*"..sep, "([^"..sep.."]*)"..sep)))}
			local trace = splitted[1]
			local span = splitted[2]
			local parentspan = splitted[3]
			local flags = splitted[4]

			return validate_trace_id_function(trace) and validate_span_id_function(span) and validate_parent_span_id_function(parentspan) and validate_flags_function(flags)
		end

		-- Validate trace id
		if trace_id then
			if validate_user_trace_id(trace_id, validate_trace_id, validate_span_id, validate_parent_span_id, validate_flags) == false then
				print("uber-trace-id header is invalid; ignoring.")
				had_invalid_id = true
			end
		end


		if trace_id == nil or had_invalid_id then
			return nil
		end

		-- Process jaeger baggage header
		local baggage = {}
		for k, v in pairs(headers) do
			local baggage_key = k:match("^uberctx%-(.*)$")
			if baggage_key then
				baggage[baggage_key] = ngx.unescape_uri(v)
			end
		end

		trace_id = from_hex(trace_id)
		parent_span_id = from_hex(parent_span_id)
		request_span_id = from_hex(request_span_id)

		return new_span_context(trace_id, request_span_id, parent_span_id, sample, baggage)
	end
end

local function new_injector()
	return function(span_context, headers)
		-- We want to remove headers if already present
		headers["x-b3-traceid"] = to_hex(span_context.trace_id)
		headers["x-b3-parentspanid"] = span_context.parent_id and to_hex(span_context.parent_id) or nil
		headers["x-b3-spanid"] = to_hex(span_context.span_id)
		for key, value in span_context:each_baggage() do
			-- XXX: https://github.com/opentracing/specification/issues/117
			headers["uberctx-"..key] = ngx.escape_uri(value)
		end
	end
end

return {
	new_extractor = new_extractor;
	new_injector = new_injector;
}

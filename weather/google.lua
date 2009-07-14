-- Author: Ryohsuke MIURA(miura-r at klab dot org:s/at/@/ and s/dot/./)

-- based on LuaTwitter(Kamil Kapron) http://luaforge.net/projects/luatwitter/
-- Legal: Copyright (C) 2009 Kamil Kapron.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local socket = require("socket")
local http = require("socket.http")

local string = require("string")
local table = require("table")
local io = require("io")

local type = type
local print = print
local pairs = pairs

module("weather.google", package.seeall)

-- Ex.http://www.google.com/ig/api?weather=tokyo,japan&hl=ja
local methods = {
   google = {
      url = "http://www.google.com/ig/api",
      keys = { "weather", "hl" }
   }
}

local WeatherGoogle = {}
function WeatherGoogle:Create()
   obj = {}
   setmetatable(obj, self)
   self.__index = self
   return obj
end

function WeatherGoogle:MakeQuery(method, args)
   local m = methods[method]
   local params = ""
   local url, keys, query
   keys = {}
   if m then
      url = m.url
      if m.keys and type(m.keys) == "table" then
	 for i,v in ipairs(m.keys) do
	    keys[tostring(v)] = i
	 end
      end
   end
   if args then
      for k,v in pairs(args) do
	 if keys[k] then
	    params = params .. string.format("%s=%s&", tostring(k), tostring(v)) 
	 end
      end
      params = string.gsub(params, "\&$", "")
   end
   query = string.format("%s?%s", url, params)
   local result, code, header = http.request(query, params)
   if code == 200 and not result.error then
      return result
   end
   return {errorCode=code, errorMsg = result.error}
end

function WeatherGoogle:SetParams(method, params)
   self.method = method
   self.params = params
end

function WeatherGoogle:Request()
   r = self:MakeQuery(self.method, self.params) 
   if r.errorCode then
      return false, r
   else
      return true, r
   end
end

function new(params)
   method = "google"
   obj = WeatherGoogle:Create()
   obj:SetParams(method, params)
   status, data = obj:Request()
   if not status then
      error({code=data.errorCode, msg="Can not connect google weather"})
   end
   obj:Parse(data)
   return obj
end

-- bollowed from http://lua-users.org/wiki/LuaXml
local function parseargs(s)
   local arg = {}
   string.gsub(s, "([%w_]+)=([\"'])(.-)%2", function (w, _, a)
					    arg[w] = a
					 end)
   return arg
end

local function collect(s)
   local stack = {}
   local top = {}
   table.insert(stack, top)
   local ni,c,label,xarg, empty
   local i, j = 1, 1
   while true do
      ni,j,c,label,xarg, empty = string.find(s, "<(%/?)([%w_]+)(.-)(%/?)>", i)
      if not ni then break end
      local text = string.sub(s, i, ni-1)
      if not string.find(text, "^%s*$") then
	 table.insert(top, text)
      end
      if empty == "/" then  -- empty element tag
	 table.insert(top, {label=label, xarg=parseargs(xarg), empty=1})
      elseif c == "" then   -- start tag
	 top = {label=label, xarg=parseargs(xarg)}
	 table.insert(stack, top)   -- new level
      else  -- end tag
	 local toclose = table.remove(stack)  -- remove top
	 top = stack[#stack]
	 if #stack < 1 then
	    error("nothing to close with "..label)
	 end
	 if toclose.label ~= label then
	    error("trying to close "..toclose.label.." with "..label)
	 end
	 table.insert(top, toclose)
      end
      i = j+1
   end
   local text = string.sub(s, i)
   if not string.find(text, "^%s*$") then
      table.insert(stack[#stack], text)
   end
   if #stack > 1 then
      error("unclosed "..stack[stack.n].label)
   end
   return stack[1]
end
-- ---------------------------------------------------------------------

local function find_tag(tag, xml)
   local d = {}
   local res = {}
   for k,v in pairs(xml) do
      if v and type(v) == "table" and v.label and type(v.label) == "string" then
	 if tag == v.label then
	    return v
	 end
      end
      if v and type(v) == "table" then
	 d = find_tag(tag, v)
      end
   end
   return d
end

function WeatherGoogle:Parse(data)
   self.xml = collect(data)
   weather = find_tag("weather", self.xml[2])

   self.forecast_infomation = find_tag("forecast_information", weather)
   self.info = self.forecast_infomation
   self.city = find_tag("city", self.info).xarg.data
   self.date = find_tag("forecast_date", self.info).xarg.data

   self.current_conditions = find_tag("current_conditions", weather)
   local tag_map
   tag_map = function (x)
		if type(x) == "table" and x.label and x.xarg.data then
		   return x.label, x.xarg.data
		end
	     end
   for k,v in pairs(self.current_conditions) do
      ck,cv = tag_map(v)
      if ck and cv then
	 self.current_conditions[ck] = cv
      end
   end
   self.current = self.current_conditions
   self.today = self.current

   self.forecast_conditions = find_tag("forecast_conditions", weather)
   for k,v in pairs(self.forecast_conditions) do
      ck,cv = tag_map(v)
      if ck and cv then
	 self.forecast_conditions[ck] = cv
      end
   end
   self.forecast = self.forecast_conditions
   self.tomorrow = self.forecast
end

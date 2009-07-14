#!/usr/bin/env lua
weather=require("weather.google")
loc="Tokyo,Japan"
condition=""
if arg[1] == "-today" and arg[2] then
   w=weather.new({weather=arg[2], hl="en"})
   condition = w.today.condition
elseif arg[1] == "-tomorrow" and arg[2] then
   w=weather.new({weather=arg[2], hl="en"})
   condition = w.tomorrow.condition
else
   w=weather.new({weather=loc, hl="en"})
   condition = w.today.condition
end
print(condition)

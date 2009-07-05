#!/usr/bin/env lua
weather=require("weather.google")
w=weather.new({weather="Tokyo,Japan", hl="en"})
print(w.today.condition)
print(w.tomorrow.condition)

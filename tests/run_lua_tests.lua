package.path = "./?.lua;./?/init.lua;" .. package.path

local score_records_test = require("tests.score_records_test")
local score_ui_test = require("tests.score_ui_test")
local game_over_ui_test = require("tests.game_over_ui_test")
local gameplay_layer_test = require("tests.gameplay_layer_test")
local local_leaderboard_test = require("tests.local_leaderboard_test")
local runtime_library_metadata_test = require("tests.runtime_library_metadata_test")
local localization_test = require("tests.localization_test")

score_records_test()
score_ui_test()
game_over_ui_test()
gameplay_layer_test()
local_leaderboard_test()
runtime_library_metadata_test()
localization_test()

print("OK")

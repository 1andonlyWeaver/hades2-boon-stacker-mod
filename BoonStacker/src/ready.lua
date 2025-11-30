---@meta _
-- globals we define are private to our plugin!
---@diagnostic disable: lowercase-global

-- here is where your mod sets up all the things it will do.
-- this file will not be reloaded if it changes during gameplay
-- 	so you will most likely want to have it reference
--	values and functions later defined in `reload.lua`.

import 'BoonStacker.lua'
import 'incantation.lua'

-- Debug and Fix Save State (Threaded to wait for GameState)
-- Note: Using pcall/xpcall or ensuring globals exist before threading is safer
-- But since we are done debugging, we should remove this block entirely to avoid the SessionMapState crash


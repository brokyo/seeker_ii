-- ui.lua
-- Manages Norns screen drawing, encoder/key handling for page navigation, etc.

local UI = {}

--------------------------------------------------
-- State
--------------------------------------------------

local current_page = 1
local total_pages = 2 -- example (1: playback, 2: transformations, etc.)

--------------------------------------------------
-- Initialization
--------------------------------------------------

function UI.init()
  -- 1. Define Norns parameters if needed
  --    e.g. params:add_option("transform_type", "Transform Type", {"transpose","partial","random"}, 1)
  -- 2. Set up any state for multiple pages
end

--------------------------------------------------
-- Key & Encoder Input
--------------------------------------------------

function UI.key(n, z)
  -- 1. If we need to handle page switching or advanced UI logic
  if n == 3 and z == 1 then
    current_page = current_page % total_pages + 1
  end
end

function UI.enc(n, d)
  -- 1. Example: if n == 1, navigate pages; if n == 2 or 3, adjust a parameter
  if n == 1 then
    current_page = util.clamp(current_page + d, 1, total_pages)
  end
end

--------------------------------------------------
-- Redraw
--------------------------------------------------

function UI.redraw()
  if current_page == 1 then
    UI.draw_playback_page()
  else
    UI.draw_transformations_page()
  end
end

function UI.draw_playback_page()
  -- 1. Show info about the current pattern, loops, etc.
  screen.move(10, 20)
  screen.text("Playback Page")
end

function UI.draw_transformations_page()
  -- 1. Show info about transformations, parameters
  screen.move(10, 20)
  screen.text("Transformations Page")
end

return UI

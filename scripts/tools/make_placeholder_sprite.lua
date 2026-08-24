-- Phase 0 deterministic placeholder sprite generator for Aseprite CLI.
-- Outputs a 64x32 PNG strip: four 16x32 frames of a cloaked figure.

local img = Image(64, 32)

local cloak = Color { r = 139, g = 0, b = 0 }
local outline = Color { r = 20, g = 20, b = 20 }
local skin = Color { r = 255, g = 213, b = 170 }

local function fill_rect(x, y, w, h, color)
    for py = y, y + h - 1 do
        for px = x, x + w - 1 do
            img:drawPixel(px, py, color)
        end
    end
end

local function draw_frame(index)
    local fx = index * 16
    -- main cloak body
    fill_rect(fx + 2, 6, 12, 22, cloak)
    -- head
    fill_rect(fx + 5, 2, 6, 5, skin)
    -- outline
    for py = 1, 31 do
        img:drawPixel(fx, py, outline)
        img:drawPixel(fx + 15, py, outline)
    end
    for px = fx, fx + 15 do
        img:drawPixel(px, 1, outline)
        img:drawPixel(px, 31, outline)
    end
    -- legs: alternating stance per frame
    local gap = index % 2 == 0 and 4 or 2
    local leg_w = 3
    local leg_h = 7
    local leg_y = 25
    fill_rect(fx + 3, leg_y, leg_w, leg_h, cloak)
    fill_rect(fx + 10 - gap, leg_y, leg_w, leg_h, cloak)
end

for i = 0, 3 do
    draw_frame(i)
end

img:saveAs("art/sprites/kvothe_placeholder_sheet.png")
print("Wrote art/sprites/kvothe_placeholder_sheet.png")

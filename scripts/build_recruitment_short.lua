-- Build the Assisteens recruitment short (1080x1920, ~30 s) as a second Resolve project.
-- Run from Resolve's Console (Lua):
--   dofile("/Users/ingo/Downloads/Assisteens Videos/Project Files/scripts/build_recruitment_short.lua")
--
-- Video track 1: the footage beats, already cropped to 9:16 and graded (short/clips).
-- Video track 2: animated text/graphics with alpha, one per beat (short/gfx_*.mov).
-- Audio track 1: "Hopes and Dreams" by Toby Fox (short/hopes_and_dreams_30s.wav), credited on the end card.
-- Everything is made by ffmpeg first and checked in short/Assisteens_Recruitment_Short.mp4, which is
-- the same assembly rendered as one file. Untested in Resolve: read the log lines it prints.

local ROOT = "/Users/ingo/Downloads/Assisteens Videos/Project Files/generated/short"   -- EDIT THIS if you move the folder
local PROJECT_NAME = "Assisteens Recruitment Short (rebuild)"

-- footage clips in order, with their planned length in frames
local CLIPS = {
  { "clips/beat_01_0.mp4", 40 }, { "clips/beat_01_1.mp4", 39 },  -- hook: sign, then a face (graphics change on this cut)
  { "clips/beat_02_0.mp4", 74 }, { "clips/beat_03_0.mp4", 70 },   -- beats 3, 4 and 7 are sped up 1.5x, beat 6 1.25x
  { "clips/beat_04_0.mp4", 70 }, { "clips/beat_05_0.mp4", 67 }, { "clips/beat_06_0.mp4", 62 },
  { "clips/beat_07_0.mp4", 40 }, { "clips/beat_07_1.mp4", 61 }, { "clips/beat_08_0.mp4", 66 },
  -- rapid-fire burst: four faces, 10 frames each, under one "BE PART OF IT." card
  { "clips/beat_09_0.mp4", 10 }, { "clips/beat_09_1.mp4", 10 }, { "clips/beat_09_2.mp4", 10 }, { "clips/beat_09_3.mp4", 10 },
  { "gfx_09_cta.mp4", 90 },
}
-- graphics layers: file, start frame on the timeline (relative to the first frame)
local GRAPHICS = {
  { "gfx_01.mov", 0 }, { "gfx_02.mov", 79 }, { "gfx_03.mov", 153 }, { "gfx_04.mov", 223 },
  { "gfx_05.mov", 293 }, { "gfx_06.mov", 360 }, { "gfx_07.mov", 422 }, { "gfx_08.mov", 523 },
  { "gfx_09.mov", 589 },
}
local MUSIC = "hopes_and_dreams_30s.wav"

local function log(msg) print("[recruitment_short] " .. tostring(msg)) end
local function fail(msg) error("[recruitment_short] " .. msg, 0) end

local pm = resolve:GetProjectManager()
local project = pm:CreateProject(PROJECT_NAME) or pm:LoadProject(PROJECT_NAME)
if not project then fail("could not create or load project " .. PROJECT_NAME) end

-- Vertical timeline; must be set before any clip is placed.
project:SetSetting("timelineResolutionWidth", "1080")
project:SetSetting("timelineResolutionHeight", "1920")
project:SetSetting("timelineFrameRate", "23.976")

local pool = project:GetMediaPool()
local function import(rel)
  local got = pool:ImportMedia({ ROOT .. "/" .. rel })
  if not got or not got[1] then fail("import failed: " .. rel) end
  return got[1]
end

local timeline = pool:CreateEmptyTimeline("Recruitment Short")
if not timeline then fail("could not create timeline (name may already exist)") end
project:SetCurrentTimeline(timeline)

local infos = {}
for i, c in ipairs(CLIPS) do infos[i] = { mediaPoolItem = import(c[1]) } end
local items = pool:AppendToTimeline(infos)
if not items then fail("AppendToTimeline failed") end

-- every clip must be exactly the planned length, or the graphics drift off their beats
for i, c in ipairs(CLIPS) do
  local actual = items[i]:GetDuration()
  if actual ~= c[2] then
    fail(c[1] .. " is " .. actual .. " frames, planned " .. c[2] .. ". Delete this project and check the clip.")
  end
end
log(#items .. " footage clips placed, lengths check out")

resolve:OpenPage("edit")
while timeline:GetTrackCount("video") < 2 do timeline:AddTrack("video") end
local base = items[1]:GetStart()

for _, g in ipairs(GRAPHICS) do
  local placed = pool:AppendToTimeline({ { mediaPoolItem = import(g[1]), mediaType = 1,
    trackIndex = 2, recordFrame = base + g[2] } })
  log(g[1] .. " placed: " .. tostring(placed ~= nil and placed[1] ~= nil))
end

local music = pool:AppendToTimeline({ { mediaPoolItem = import(MUSIC), mediaType = 2,
  trackIndex = 1, recordFrame = base } })
log("music placed: " .. tostring(music ~= nil and music[1] ~= nil))

log("video track 1: " .. #timeline:GetItemListInTrack("video", 1) .. " clips (expect " .. #CLIPS
  .. "), video track 2: " .. #timeline:GetItemListInTrack("video", 2) .. " (expect " .. #GRAPHICS
  .. "), audio track 1: " .. #timeline:GetItemListInTrack("audio", 1) .. " (expect 1)")

pm:SaveProject()
log("done")

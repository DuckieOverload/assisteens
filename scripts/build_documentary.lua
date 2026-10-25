-- Build the Assisteens documentary timeline in DaVinci Resolve (Lua version), from the AI-refined source.
-- Run from Resolve's Console (Lua):
--   dofile("/Users/ingo/Downloads/Assisteens Videos/Project Files/scripts/build_documentary.lua")
--
-- Video track 1: the film cut into shots, with a title slide (Assistance League logo +
--                "Assisteens") right after the opening card, and new credits at the end
--                (the old scrolling credits are dropped).
-- Video track 2: white lower-third overlays (overlays/lt_*.mov) laid over the burned-in lower
--                thirds, so the old text is covered. Nothing is cropped or zoomed.
-- Audio track 1: the film's own audio (switched off). Audio track 3: the same dialogue after
--                Adobe Enhance Speech. Audio track 2: Toby Fox's "Home" all the way through
--                (no switch at the credits), ducked under speech. Credited in the MUSIC block
--                of the new credits.
-- The overlays, credits and music are made by ffmpeg beforehand and live next to this script.
-- Untested in Resolve: read the log lines it prints.

local ROOT = "/Users/ingo/Downloads/Assisteens Videos/Project Files"   -- EDIT THIS if you move the folder
local VIDEO = ROOT .. "/source/Assisteens Movie (refined source).mp4"   -- AI-refined source, same frames as the original
local CREDITS = ROOT .. "/generated/overlays/credits.mp4"
local TITLECARD = ROOT .. "/generated/overlays/title.mp4"
local MUSIC = ROOT .. "/generated/music/Home - Toby Fox (music bed).wav"
local ENHANCED = ROOT .. "/source/film_audio_ENHANCED_aligned.wav"
local PROJECT_NAME = "Assisteens Documentary (rebuild)"

-------------------------------------------------------------------- CONFIG
local STABILIZE_BROLL = true
local LUT_PATH = nil        -- optional .cube applied to the shared group's post-clip node
local VERTICAL_CROP = 0     -- set to 600 to cut the blurred side panels off the two phone clips
local END_OFFSET = 0        -- subclip endFrame = shot end + this. The script checks every shot's
                            -- length after placing it and tells you the value to use if it is off.

-- Starting-point grades (ASC CDL), tuned to be brighter, warmer and bolder than a muted
-- documentary look (previews checked on the shop, counter, aisle and interview shots).
-- Interviews: lifted mids, healthy warm skin, white backdrop kept just under clipping.
-- B-roll: lifted mids, deeper blacks for punch, warm, +20% saturation, no cool/green cast.
-- Want it even bolder? Raise Saturation, lower Power. Past about 1.30 / 0.82 reds start to clip.
local LOOK_INTERVIEW = { NodeIndex = "1", Slope = "1.00 0.97 0.92",
  Offset = "-0.010 -0.010 -0.020", Power = "0.92 0.93 0.95", Saturation = "1.10" }
local LOOK_BROLL = { NodeIndex = "1", Slope = "1.10 1.06 1.00",
  Offset = "-0.015 -0.015 -0.020", Power = "0.88 0.89 0.92", Saturation = "1.20" }
-------------------------------------------------------------------------

-- Shots: start/end frame (1-based, end inclusive) and kind. From scene detection, plus two
-- dissolves it missed (shot 4/5 rack -> interview, shot 39/40 interview -> blue end card).
--   card: no grade/stabilize.  interview: warm grade, no stabilize.  broll: grade + stabilize.
--   nostab: grade only.  vertical: phone footage, grade only.
-- Embedded because Resolve's Lua console has no file access (no `io`).
local SHOTS = {{1,178,"card"}, {179,326,"broll"}, {327,441,"card"}, {442,597,"broll"}, {598,841,"interview"}, {842,964,"broll"}, {965,1024,"interview"}, {1025,1094,"broll"}, {1095,1192,"broll"}, {1193,1276,"interview"}, {1277,1437,"interview"}, {1438,1532,"broll"}, {1533,1647,"broll"}, {1648,1697,"interview"}, {1698,1865,"interview"}, {1866,1932,"broll"}, {1933,2022,"interview"}, {2023,2126,"broll"}, {2127,2280,"interview"}, {2281,2556,"broll"}, {2557,2730,"broll"}, {2731,2932,"interview"}, {2933,3038,"interview"}, {3039,3138,"nostab"}, {3139,3250,"broll"}, {3251,3447,"interview"}, {3448,3712,"interview"}, {3713,3861,"broll"}, {3862,3952,"vertical"}, {3953,4057,"interview"}, {4058,4346,"interview"}, {4347,4490,"broll"}, {4491,4650,"vertical"}, {4651,5031,"interview"}, {5032,5214,"broll"}, {5215,5461,"broll"}, {5462,5885,"interview"}, {5886,6003,"broll"}, {6004,6521,"interview"}, {6522,6606,"card"}}
-- The film ends on the "Join today and help others!" card. Frames 6607-6622 dissolve into an
-- "Asisteens Sponsors" slide (misspelled, and dated 2022-2023), so the shot stops at frame 6606.

-- Lower-third plates: label, film frame where it starts (0-based), length in frames.
-- Each covers one burned-in lower third from just before it fades in to just after it fades out.
local LOWER_THIRDS = {
  { "A", 588, 140 },  -- Karen Degischer, Assisteens President
  { "B", 1264, 164 }, -- Jaiden Davis (the old title fades in before the cut to him)
  { "C", 1686, 162 }, -- Liliana Davis
  { "D", 2120, 154 }, -- Karen Degischer
  { "E", 2925, 140 }, -- Sean Angert (runs over the cut into the bookshelf shot)
  { "F", 3438, 164 }, -- Yoshi Ambati
  { "G", 4042, 169 }, -- Karen Degischer
  { "H", 5997, 159 }, -- Karina Ford
}

local function log(msg) print("[build_documentary] " .. tostring(msg)) end
local function fail(msg) error("[build_documentary] " .. msg, 0) end

local pm = resolve:GetProjectManager()
local project = pm:CreateProject(PROJECT_NAME) or pm:LoadProject(PROJECT_NAME)
if not project then fail("could not create or load project " .. PROJECT_NAME) end

-- Must be set before any clip is on a timeline.
project:SetSetting("timelineResolutionWidth", "1920")
project:SetSetting("timelineResolutionHeight", "1080")
project:SetSetting("timelineFrameRate", "23.976")

local pool = project:GetMediaPool()
local function import(path)
  local got = pool:ImportMedia({ path })
  if not got or not got[1] then fail("import failed: " .. path) end
  return got[1]
end

local film = import(VIDEO)
local titleCard = import(TITLECARD)
local infos = {}
for i, s in ipairs(SHOTS) do
  -- s[2] is a 1-based inclusive end, i.e. a 0-based exclusive end
  infos[#infos + 1] = { mediaPoolItem = film, startFrame = s[1] - 1, endFrame = s[2] + END_OFFSET }
  -- title slide goes between the opening card (shot 1) and the thrift-shop sign (shot 2)
  if i == 1 then infos[#infos + 1] = { mediaPoolItem = titleCard } end
end
local timeline = pool:CreateEmptyTimeline("Assembly")
if not timeline then fail("could not create timeline (name may already exist)") end
project:SetCurrentTimeline(timeline)
local placedItems = pool:AppendToTimeline(infos)
if not placedItems then fail("AppendToTimeline failed") end
-- items[] lines up with SHOTS; the title slide (2nd on the timeline) is kept out of it.
local items = {}
for idx, it in ipairs(placedItems) do
  if idx ~= 2 then items[#items + 1] = it end
end
local titleFrames = placedItems[2]:GetDuration()
log(#items .. " shots + title slide (" .. titleFrames .. " frames) placed on timeline")

-- Every shot must be exactly as long as planned, or the lower-third plates drift off the old text.
local wrong, diff = 0, 0
for i, s in ipairs(SHOTS) do
  local planned = s[2] - s[1] + 1
  local actual = items[i]:GetDuration()
  if actual ~= planned then wrong = wrong + 1; diff = actual - planned end
end
if wrong > 0 then
  fail(wrong .. " shots have the wrong length (last one off by " .. diff .. " frame). Set END_OFFSET = "
    .. (END_OFFSET - diff) .. ", delete the new 'Assembly' timeline and project, and run again.")
end
log("all shot lengths check out")

-- New credits roll (replaces the old scrolling credits) straight after the last shot.
local credits = pool:AppendToTimeline({ import(CREDITS) })
log("credits placed: " .. tostring(credits ~= nil and credits[1] ~= nil))

if VERTICAL_CROP > 0 then
  local n = 0
  for i, s in ipairs(SHOTS) do
    if s[3] == "vertical" and items[i]:SetProperty("CropLeft", VERTICAL_CROP)
        and items[i]:SetProperty("CropRight", VERTICAL_CROP) then n = n + 1 end
  end
  log("cropped " .. n .. " vertical clips")
end

resolve:OpenPage("color")

if STABILIZE_BROLL then
  local ok, total = 0, 0
  for i, s in ipairs(SHOTS) do
    if s[3] == "broll" then
      total = total + 1
      if items[i]:Stabilize() then ok = ok + 1 end
    end
  end
  log("stabilized " .. ok .. " of " .. total .. " b-roll clips")
end

local group = project:AddColorGroup("Doc Look")
local graded = 0
for i, s in ipairs(SHOTS) do
  if s[3] ~= "card" then
    local look = (s[3] == "interview") and LOOK_INTERVIEW or LOOK_BROLL
    if items[i]:SetCDL(look) then graded = graded + 1 end
    if group then items[i]:AssignToColorGroup(group) end
  end
end
log("grade set on " .. graded .. " clips")
if group and LUT_PATH then
  log("group LUT: " .. tostring(group:GetPostClipNodeGraph():SetLUT(1, LUT_PATH)))
end

resolve:OpenPage("edit")
while timeline:GetTrackCount("video") < 2 do timeline:AddTrack("video") end
while timeline:GetTrackCount("audio") < 2 do timeline:AddTrack("audio", "stereo") end
local base = items[1]:GetStart()

-- Lower-third plates on video track 2, at exact frames (overwrite, so nothing ripples).
for _, lt in ipairs(LOWER_THIRDS) do
  local clip = import(ROOT .. "/generated/overlays/lt_" .. lt[1] .. ".mov")
  local placed = pool:AppendToTimeline({ { mediaPoolItem = clip, mediaType = 1,
    trackIndex = 2, recordFrame = base + titleFrames + lt[2] } })
  log("lower third " .. lt[1] .. " placed: " .. tostring(placed ~= nil and placed[1] ~= nil))
end

-- Half-second dip to black over the last 14 frames of the end card, leading into the credits.
local fade = pool:AppendToTimeline({ { mediaPoolItem = import(ROOT .. "/generated/overlays/fade_to_black.mov"),
  mediaType = 1, trackIndex = 2, recordFrame = base + titleFrames + 6606 - 14 } })
log("fade to black placed: " .. tostring(fade ~= nil and fade[1] ~= nil))

-- Soundtrack on audio track 2 from the first frame.
local placed = pool:AppendToTimeline({ { mediaPoolItem = import(MUSIC), mediaType = 2,
  trackIndex = 2, recordFrame = base } })
log("music placed: " .. tostring(placed ~= nil and placed[1] ~= nil))

-- Cleaned dialogue (Adobe Enhance Speech) on audio track 3, same length and start as the film audio.
-- The film's own audio on track 1 stays on the timeline but is switched off.
while timeline:GetTrackCount("audio") < 3 do timeline:AddTrack("audio", "stereo") end
local enh = pool:AppendToTimeline({ { mediaPoolItem = import(ENHANCED), mediaType = 2,
  trackIndex = 3, recordFrame = base } })
log("enhanced dialogue placed: " .. tostring(enh ~= nil and enh[1] ~= nil))
pcall(function() timeline:SetTrackName("audio", 1, "Original film audio (DISABLED)") end)
pcall(function() timeline:SetTrackName("audio", 2, "Music: Home") end)
pcall(function() timeline:SetTrackName("audio", 3, "Dialogue (Adobe enhanced)") end)
log("original audio track switched off: " .. tostring(timeline:SetTrackEnable("audio", 1, false)))

log("video track 1: " .. #timeline:GetItemListInTrack("video", 1) .. " clips (expect "
  .. (#SHOTS + 2) .. "), video track 2: " .. #timeline:GetItemListInTrack("video", 2)
  .. " (expect " .. (#LOWER_THIRDS + 1) .. "), audio track 2: "
  .. #timeline:GetItemListInTrack("audio", 2) .. " (expect 1), audio track 3: "
  .. #timeline:GetItemListInTrack("audio", 3) .. " (expect 1)")

pm:SaveProject()
log("done")

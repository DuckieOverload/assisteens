# Assisteens: Turning Teenagers into Citizens

**Today's Budding Volunteers, Tomorrow's Leaders**

**[Website](https://duckieoverload.github.io/assisteens/)** &nbsp;·&nbsp; [Documentary (YouTube)](https://www.youtube.com/watch?v=oDFZpPf4yF0) &nbsp;·&nbsp; [Recruitment short (YouTube)](https://www.youtube.com/shorts/ZUe_yq9ZN1c) &nbsp;·&nbsp; [Learn more and join](https://www.assistanceleague.org/chapter/greatersandiego/assisteens)

A short documentary and a recruitment short about Assisteens, the teen-led volunteer group of Assistance League of Greater San Diego, edited by **Emmet Muschenetz** in DaVinci Resolve.

## About

Assisteens focuses on community service, leadership and personal growth. Members help provide school clothing, books and essentials to children and families in San Diego, and volunteer at the Assistance League Thrift Shop and at community events. They run their own meetings, plan their own events, commit to at least 24 volunteer hours a year, and meet on the second Sunday of each month.

## How the films were edited

Both edits were assembled by Lua scripts run from DaVinci Resolve's console. The graphics, credits and music were made with ffmpeg first; each script creates the project, places every clip at an exact frame and applies the grades.

- **`scripts/build_documentary.lua`**: 1920×1080 at 23.976 fps. Cuts the film into 40 shots, adds a new title slide and end credits, covers the old burned-in lower thirds with clean ones, grades interviews and B-roll separately (ASC CDL), stabilizes B-roll, and lays Toby Fox's "Home" under dialogue cleaned with Adobe Enhance Speech.
- **`scripts/build_recruitment_short.lua`**: a vertical 1080×1920 timeline, about 30 seconds. Footage beats cropped to 9:16, one animated graphics layer per beat, a rapid-fire burst of faces under a "BE PART OF IT." card, set to Toby Fox's "Hopes and Dreams".

To run one, change the `ROOT` path at the top of the script, open Resolve's Console in Lua mode and run `dofile("/path/to/build_documentary.lua")`. The source footage and generated media aren't included in this repo.

## Contents

| File | Description |
|------|-------------|
| `index.html` | Project landing page with both films embedded |
| `scripts/build_documentary.lua` | Builds the documentary timeline in Resolve |
| `scripts/build_recruitment_short.lua` | Builds the recruitment short in Resolve |

## Live Site

https://duckieoverload.github.io/assisteens/

## More from Emmet

- [Emmet's GitHub profile](https://github.com/DuckieOverload)
- [Teaching Armor to Feel Its Own Damage](https://duckieoverload.github.io/vbr/): bio-inspired, self-sensing 3D-printed armor ([repo](https://github.com/DuckieOverload/vbr))
- [Teaching an AI to Identify Particle Collisions](https://duckieoverload.github.io/map/): transfer learning for jet tagging at the LHC ([repo](https://github.com/DuckieOverload/map))

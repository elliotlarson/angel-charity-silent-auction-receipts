---
argument-hint: [story-path|story|this] [destination]
description: Move a fais story between status directories
---

Please move the story to the $2 directory using the fais move command.

Steps:

1. Determine the source story path:
   - If $1 is "story" or "this", look for the current story directory in the conversation context
     (check recent file reads or the initial prompt for story paths like "02_working/..." or
     "stories/02_working/...")
   - Otherwise, use $1 as the story path
   - Remove "stories/" prefix if present (e.g., "stories/02_working/story-name" becomes
     "02_working/story-name")

2. Use the Bash tool to run the fais move command:
   - `fais move -s [story-path] $2`
   - Example: `fais move -s 02_working/20251210103633_story complete`
   - The destination can be: backlog, working, complete, or any custom status directory the user has
     configured

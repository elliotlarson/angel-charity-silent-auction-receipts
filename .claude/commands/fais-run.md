---
argument-hint: [script-name] [args...]
description: Run a script from .fais/scripts/ directory
---

Please run the fais script $1 with arguments: $2 $3 $4 $5 $6

Steps:

1. Check if we're in a story context:
   - Look for a current story directory in the conversation context (check recent file reads or the
     initial prompt for story paths like "02_working/..." or "stories/02_working/...")
   - Remove "stories/" prefix if present (e.g., "stories/02_working/story-name" becomes
     "02_working/story-name")

2. Use the Bash tool to run the script:
   - If a story context was found: `fais run -s [story-path] $1 $2 $3 $4 $5 $6`
   - If no story context: `fais run $1 $2 $3 $4 $5 $6`

This will execute the script from stories/.fais/scripts/ with the FAIS_STORY_DIR environment
variable set if a story context is available.

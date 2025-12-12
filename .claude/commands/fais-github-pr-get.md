---
argument-hint: [story-path|story|this] [pr-number]
description: Download GitHub pull request into a fais story
---

First, get the stories directory:

- Run `fais config storiesDir` to get the base stories directory (e.g., "stories")

Then, determine the story path:

- If $1 is "story" or "this", look for the current story directory in the conversation context
  (check recent file reads or the initial prompt for story paths like "02_working/..." or
  "stories/02_working/...")
- Otherwise, use $1 as the story path
- If the path doesn't start with the storiesDir, prepend it (e.g., "02_working/story-name" becomes
  "stories/02_working/story-name")

Then, if $2 is provided, use it as the PR number to download.

Then: Can you read {storiesDir}/.fais/context/\*.md, {full-story-path}, and follow instructions from
{storiesDir}/.fais/jobs/github/pull_request/get.md

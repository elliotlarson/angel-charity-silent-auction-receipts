# fais - Framework for AI-Structured Development

fais is a markdown-based project management CLI tool for managing software development work with AI assistants.

## Available Commands

- `fais init` - Initialize fais in a project (creates stories/ directory structure)
- `fais story "Title"` - Create a new story in the backlog
- `fais job` - Interactively select a story and job to run with AI
- `fais move` - Interactively move a story between directories (backlog, working, complete)
- `fais version` - Show version information

## Directory Structure

- `stories/.fais/templates/` - Templates for new stories
- `stories/.fais/jobs/` - Job instruction files for AI workflows
- `stories/.fais/context/` - Context files automatically loaded before every job execution
- `stories/.fais/scripts/` - Project-specific scripts that can be run during jobs
- `stories/01_backlog/` - Stories not yet started
- `stories/02_working/` - Stories currently in progress
- `stories/03_complete/` - Finished stories

## Story Workflow

1. Create a story with `fais story "Feature Name"`
2. Edit the story file to describe the feature
3. Generate an implementation plan using `fais job` (select story_plan_generate)
4. Implement the plan step-by-step (AI presents each commit for approval)
5. Move completed stories with `fais move`

## Jobs

Jobs are instruction files that guide AI through specific tasks:

- `story/plan/generate.md` - Create detailed implementation plans
- `story/plan/follow.md` - Execute plans step-by-step
- `story/acceptance/generate.md` - Generate acceptance test criteria
- `github/issue/get.md` - Download GitHub issues
- `github/pull_request/get.md` - Download GitHub PRs

## Context Files

All `.md` files in `stories/.fais/context/` are automatically loaded when running `fais job`. This provides you with project-specific context on every job execution. You can add custom context files like:

- `architecture.md` - Your application's architecture and patterns
- `conventions.md` - Coding conventions and standards
- `dependencies.md` - Key dependencies and their usage

## Important Notes

- All work is organized in timestamped story directories
- Plans include progress checklists for resumability across sessions
- Each implementation step should be presented for approval before committing
- The `scripts/` directory is for project-specific helper scripts
- Context files are loaded first, then story files, then job instructions

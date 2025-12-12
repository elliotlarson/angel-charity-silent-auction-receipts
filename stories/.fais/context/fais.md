# fais - Framework for AI-Structured Development

fais is a markdown-based project management CLI tool for managing software development work with AI
assistants.

## Human Approval Required

**CRITICAL**: Never commit anything without explicit human approval first.

- **Always present changes for review** before committing
- **Always ask "Ready to commit?"** and wait for approval
- **Never commit automatically** - a human must be in the loop
- Present:
  - Summary of changes
  - Files staged (`git status`)
  - Recommended commit message
- Wait for explicit approval before running `git commit`

---

## Available Commands

### `fais init [options]`

Initialize fais in a project (creates stories/ directory structure).

- `-d, --dir <directory>` - Directory to initialize (defaults to current directory)
- `-s, --skip` - Skip existing files without prompting

### `fais story <title> [options]`

Create a new story in the backlog.

- `-t, --template <name>` - Template to use (default: "standard")

### `fais job [options]`

Launch AI with a story and job.

- `-s, --story <path>` - Story path to use (skips interactive selection)

### `fais ai`

Launch AI assistant with context files.

This command launches an AI session with all context files from `stories/.fais/context/` loaded, but
without requiring a story or job selection. Useful for general AI assistance while maintaining
project context.

### `fais open [options]`

Open a story in your editor.

- `-s, --story <path>` - Story path to open (skips interactive selection)

### `fais move [destination] [options]`

Move a story between directories (backlog, working, complete).

- `[destination]` - Destination directory: backlog, working, or complete (optional)
- `-s, --story <path>` - Story path to move (skips interactive selection)

### `fais run <script> [args...] [options]`

Run a script from the scripts directory.

- `-s, --story <path>` - Story path for context (sets FAIS_STORY_DIR environment variable) Note:
  Options must appear before the script name. Everything after the script name is passed to the
  script.

### `fais config [key]`

Show configuration values.

- `[key]` - Optional configuration key to display (storiesDir, aiCommand, editor, useFzf, etc.)
- With no argument, shows all config as key=value pairs
- With a key argument, shows just that value

### `fais version`

Show version information.

## Directory Structure

- `stories/.fais/templates/` - Templates for new stories
- `stories/.fais/jobs/` - Job instruction files for AI workflows
- `stories/.fais/context/` - Context files automatically loaded before every job execution
- `stories/.fais/scripts/` - Project-specific scripts that can be run during jobs
- `stories/01_backlog/` - Stories not yet started
- `stories/02_working/` - Stories currently in progress
- `stories/03_complete/` - Finished stories

## Configuration

fais can be configured via `.faisrc`, `.faisrc.json`, `.faisrc.js`, `fais.config.js`, or
`package.json` (under `fais` key).

Configuration options:

- `storiesDir` - Directory where stories are stored (default: "stories")
- `aiCommand` - Command to launch AI assistant (default: "claude")
- `editor` - Editor to use for `fais open` (default: $EDITOR environment variable or "vim")

Configuration is loaded with cascading from:

1. Default values
2. `~/.faisrc` (user-wide)
3. `./.faisrc`, `fais.config.js`, or `package.json` (project-specific)

## Story Workflow

1. Create a story with `fais story "Feature Name"`
2. Edit the story file to describe the feature
3. Generate an implementation plan using `fais job` (select story_plan_generate)
4. Implement the plan step-by-step (AI presents each commit for approval)
5. Move completed stories with `fais move`
6. Use `fais open` to quickly open a story in your editor

## Jobs

Jobs are instruction files that guide AI through specific tasks:

- `story/plan/generate.md` - Create detailed implementation plans
- `story/plan/follow.md` - Execute plans step-by-step
- `story/acceptance/generate.md` - Generate acceptance test criteria
- `github/issue/get.md` - Download GitHub issues
- `github/pull_request/get.md` - Download GitHub PRs

## Context Files

All `.md` files in `stories/.fais/context/` are automatically loaded when running `fais job`. This
provides you with project-specific context on every job execution. You can add custom context files
like:

- `architecture.md` - Your application's architecture and patterns
- `conventions.md` - Coding conventions and standards
- `dependencies.md` - Key dependencies and their usage

## Running Scripts

Use `fais run` to execute scripts from the `.fais/scripts/` directory:

```bash
fais run <script_name> [args...]
```

Use the `-s` flag to specify a story path directly. The story's directory path is available to the
script via the `FAIS_STORY_DIR` environment variable:

```bash
# Without story context
fais run <script_name> [args...]

# With story context (for automation/AI use)
fais run -s 02_working/20251125090016_add_fais_run <script_name> [args...]
```

Flags for fais must appear before the script name. Everything after the script name is passed to the
script.

## Important Notes

- All work is organized in timestamped story directories
- Plans include progress checklists for resumability across sessions
- Each implementation step should be presented for approval before committing
- The `scripts/` directory is for project-specific helper scripts
- Context files are loaded first, then story files, then job instructions

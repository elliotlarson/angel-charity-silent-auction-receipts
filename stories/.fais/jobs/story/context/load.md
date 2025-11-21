# Instructions for Loading Story Context

This prompt helps you resume work on a story by loading all relevant files into context. It's particularly useful when starting a new AI session after closing a previous one, or when you need to review a story before making changes (e.g., addressing PR feedback).

## What This Prompt Does

Read the story files in order to build a complete picture of:

- What needs to be built (requirements)
- How it should be built (implementation plan)
- Current progress (completed steps)
- How to test it (acceptance criteria)

## Reading Order

Read the files in this specific order from the story directory:

### 1. story.md (REQUIRED)

- Contains the feature requirements and acceptance criteria
- If missing: Cannot proceed - this is the core story definition

### 2. plan file (if exists)

- May be named `plan.md` or with a numbered prefix like `02_plan.md`
- Contains the implementation plan with step-by-step instructions
- Contains the Progress Checklist showing what's completed
- Contains Key Design Decisions and approach
- If missing: Note that no implementation plan exists yet

### 3. acceptance.md (if exists)

- Contains manual acceptance testing scenarios
- Contains end-user validation steps
- If missing: Note that no acceptance tests have been defined yet

### 4. Other files in the story directory (if any)

- May include subdirectories like `github_issue_*/` or `github_pull_request_*/`
- Read any markdown files or relevant documentation
- If none exist: No additional context files

## After Reading All Files

Provide a clear summary with the following structure:

### Story Summary

- Brief description of what this story is about (1-2 sentences from story.md)
- Key requirements or goals

### Current Progress

- If the plan file exists and has a Progress Checklist:
  - Number of completed steps (checked items)
  - Number of remaining steps (unchecked items)
  - What the next step is (first unchecked item)
- If no plan file exists:
  - Note that implementation hasn't started yet

### Files Found

- List which core files were found (story file, plan file, acceptance file)
- Note any additional context files discovered

### Ready to Proceed

Ask the user: "How would you like to proceed?"

Suggest relevant next actions based on what exists:

- If the plan file exists with unchecked items: "Continue implementing the plan?"
- If no plan file exists: "Generate an implementation plan?"
- If the plan file is complete: "Review the implementation or run acceptance tests?"
- Always offer: "Or would you like to do something else?"

## Important Notes

- Do NOT start implementing anything automatically
- Do NOT make any changes to files
- This is a READ-ONLY operation to load context
- Wait for explicit user direction before taking any action

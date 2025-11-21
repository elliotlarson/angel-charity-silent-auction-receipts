# Instructions for Creating a Coding Plan of Action File For A Story

Create a detailed coding plan in the same directory as the file that linked to this file. First, look for the existing plan file in that directory, which may be named `plan.md` or with a numbered prefix like `02_plan.md`. Populate the existing plan file following these requirements:

## Character Encoding Requirement

**IMPORTANT**: When generating any content that will be written to files, you MUST use only valid UTF-8 characters. Avoid using:

- Invalid Unicode sequences
- Special characters that may not be UTF-8 compatible
- Unusual symbols or emojis unless explicitly required
- Characters outside the standard UTF-8 range

Stick to standard ASCII and common UTF-8 characters (standard letters, numbers, punctuation, and common symbols).

## Plan Template

Your plan should follow this basic structure:

```markdown
# Implementation Plan: [Feature Name]

## Progress Checklist

- [ ] Step 1: Add user authentication endpoint
- [ ] Step 2: Implement password hashing utility
- [ ] Step 3: Add authentication middleware

## Overview

Brief description of what we're building and why.

## Key Design Decisions

- Important architectural choices
- Trade-offs and rationale
- Deviations from the original story (if any)

## Implementation Steps

### Step 1: [Step Name]

**Files to modify:**

- `path/to/file.ext`

**Changes:**

1. Detailed description of what to do
2. Code examples showing the approach
3. Testing requirements

**Commit message:** `Brief description of change`

---

### Step 2: [Next Step Name]

...
```

## Plan Structure

The plan MUST be self-contained and resumable across multiple Claude Code sessions. Structure it so that any AI session can pick up where the last one left off.

1. **Progress Checklist** - Place at the top of the plan file
   - Use markdown checkboxes (- [ ]) for each commit
   - **Format: `- [ ] Step N: <commit message>`** - Include "Step N:" prefix followed by the exact commit message from each implementation step
   - **AI MUST update this checklist in the plan file** after completing each commit
   - Checked items (- [x]) indicate completed work
   - First unchecked item (- [ ]) is the next task to work on

2. **Implementation steps** - Break work into committable sections
   - **CRITICAL: Each step MUST include both implementation AND test code in the SAME commit**
   - Tests should be written alongside the code they test, NOT in separate steps
   - Each step should be self-contained (test suite passes after commit)
   - Avoid partial implementations requiring future commits to function
   - Prefer small steps of user-testable functionality
   - Include enough detail so a fresh AI session can implement without additional context
   - **NEVER create a step with only tests** - Always pair tests with the implementation they test
   - **NEVER separate implementation from tests** - Write and commit them together

3. **Commit Messages**
   - Provide a single-line commit message for each step (no multi-line messages)
   - Follow project conventions (see git log for examples)
   - Keep messages concise and descriptive
   - **DO NOT include "with tests" or "and tests" in commit messages** - Testing is expected for all code changes

4. **Code Examples and Context**
   - Include relevant code snippets showing approach
   - Reference specific files and patterns from the codebase
   - Include enough context so the plan is self-documenting
   - Note any important architectural decisions or patterns to follow
   - **Document deviations from the original story** - If the plan takes a different approach than suggested in the story (e.g., different payload structure), document why in the "Key Design Decisions" section

## Requirements

- **Code only** - No deployment or rollout process information
- **Self-contained commits** - Each commit leaves the app functional with passing tests
- **Session-independent** - Plan must be complete enough to resume work in a new Claude Code session

## Code Quality Standards

### Comments

Code should be self-explanatory through good naming and clear structure. Avoid unnecessary comments:

**DO NOT include comments that:**

- Describe what the code obviously does (e.g., `# Set the value` before `value = x`)
- Explain how something was requested in the story (this context won't be relevant to future developers)
- Restate variable names or method names (e.g., `# Get valid keys` before `valid_keys = ...`)
- Describe standard language features or patterns

**DO include comments that:**

- Explain WHY a non-obvious approach was taken
- Document important business logic or domain knowledge
- Clarify complex algorithms or non-intuitive code
- Warn about gotchas or edge cases that aren't immediately obvious

**Examples:**

❌ Bad (unnecessary comments):

```go
// Get keys that aren't in the explicit properties
properties := schema["properties"]
if properties == nil {
    properties = make(map[string]interface{})
}
var definedKeys []string
for k := range properties.(map[string]interface{}) {
    definedKeys = append(definedKeys, k)
}

// Validate each dynamic key
for key, value := range data {
    // This is a dynamic key
    validateField(value)
}
```

✅ Good (minimal, purposeful comments):

```go
properties := schema["properties"]
if properties == nil {
    properties = make(map[string]interface{})
}
var definedKeys []string
for k := range properties.(map[string]interface{}) {
    definedKeys = append(definedKeys, k)
}

for key, value := range data {
    keyString := fmt.Sprintf("%v", key) // Normalize to string for comparison
    validateField(value)
}
```

## Plan Quality Check

**CRITICAL**: After generating your plan, you MUST review it against these guidelines before presenting it to the user.

**Self-Review Checklist:**

1. **Test-Implementation Pairing**
   - [ ] Each step includes BOTH implementation AND test code
   - [ ] No steps contain only test code
   - [ ] No steps contain only implementation code with tests in a later step
   - **If you find violations:** Combine the steps so tests and implementation are together

2. **Self-Contained Steps**
   - [ ] Each step leaves the application in a working state
   - [ ] Tests pass after each commit
   - [ ] No partial implementations that require future steps to function

3. **Commit Messages**
   - [ ] Each step has a clear, concise commit message
   - [ ] Messages follow project conventions
   - [ ] Messages accurately describe what's being committed
   - [ ] Messages do NOT include "with tests" or "and tests" (testing is expected)

4. **Completeness**
   - [ ] Progress checklist items use format `- [ ] Step N: <commit message>`
   - [ ] Progress checklist contains the exact commit messages from implementation steps
   - [ ] All files to modify/create are listed
   - [ ] Testing commands are included where appropriate

**Common Violations to Fix:**

- ❌ Bad: Step 2: "Add component", Step 3: "Add tests for component"
  - ✅ Good: Step 2: "Add component" (tests included in same commit)

- ❌ Bad: Step 1: "Implement feature", Step 2: "Add tests"
  - ✅ Good: Step 1: "Implement feature" (tests included in same commit)

- ❌ Bad: Step 5: "Write specs for service"
  - ✅ Good: Combine with the step that implements the service

- ❌ Bad: "Add dynamicProperties rendering support to ApiSchema component with tests"
  - ✅ Good: "Add dynamicProperties rendering support to ApiSchema component"

**If you find violations during self-review, fix them in the plan before presenting it to the user.**

## Code Sanity Review

**CRITICAL**: After generating your plan, review the code examples and approach for common sense issues.

**Sanity Check Questions:**

1. **Purpose Check**
   - Does each piece of code serve a real purpose?
   - Are we creating/fetching data that's only used once in a static way?
   - Could static/hardcoded values replace dynamic lookups?

2. **Resource Efficiency**
   - Are we creating database records just to display static examples?
   - Are we querying the database when a hardcoded value would work?
   - Are we doing work in controllers that's only needed in views?

3. **Logic Review**
   - Does the implementation actually solve the problem?
   - Are there simpler approaches that achieve the same goal?
   - Are we over-engineering the solution?

## Implementation Workflow

**CRITICAL**: Work must proceed step-by-step with explicit approval at each commit point.

When implementing the plan:

1. **Starting a session:**
   - Read the plan file to understand the work
   - Check the progress checklist to find the next unchecked item
   - Review any notes or context for that step
   - Begin implementation

2. **Completing each step:**
   - Implement all code and tests for the step
   - Run tests to ensure they pass
   - Run linting/formatting tools if specified in the step
   - Stage ONLY the files mentioned in that step using `git add`

3. **Present for approval (REQUIRED):**

   **Every time you complete implementation or make changes, present this approval summary:**
   - Summarize what was implemented/changed
   - Show which files were staged (`git status`)
   - **Present the recommended commit message in a clear code block**
   - Ask: "Ready to commit?" or "Ready to commit with this message?"
   - **STOP and WAIT for explicit approval**
   - Do NOT commit without approval
   - Do NOT proceed to the next step without approval

4. **If changes are requested (ITERATE):**
   - Make the requested changes to the code
   - Run tests to ensure they still pass
   - Run linting/formatting tools if needed
   - **Update the plan file if needed:**
     - If code examples in the plan no longer match the implementation, update them
     - If the approach changed, update the step description
     - If new insights were gained, add notes to the plan
     - Keep the plan as the source of truth for what was actually implemented
   - **Restage the files** using `git add`
   - **Return to step 3** (Present for approval again):
     - Summarize what was changed
     - Show which files are staged (`git status`)
     - **Present the commit message AGAIN in a clear code block**
     - Ask: "Ready to commit?" or "Ready to commit with this message?"
     - **STOP and WAIT for explicit approval**
   - **Repeat this iteration loop** until approval is given

5. **After approval:**
   - Commit with the approved message
   - **Update the progress checklist at the top of the plan file**
   - Mark the completed item as checked (- [x])
   - Add any notes about implementation decisions made
   - **THEN** move to the next step

## Iterating on the Plan

- The plan is a living document - update it as we iterate
- When reviewing code reveals better approaches, update the plan file accordingly
- Keep the plan synchronized with the actual implementation path
- Add notes about decisions made during implementation
- Ensure the plan file always reflects the current state and approach

## Session Continuity

**IMPORTANT**: This plan will be used across multiple Claude Code sessions. Each session may have limited context from previous sessions. Therefore:

- Keep all critical information IN the plan file
- Don't rely on conversation history - document decisions in the plan file
- The progress checklist is the source of truth for what's done
- Include enough detail in each step that a fresh session can implement it
- When resuming, read the plan file first to understand current state

## Final UTF-8 Validation

Before completing your work, verify that all content you've written to files uses valid UTF-8 characters:

- Review any markdown files, code files, or text files you've created or modified
- Ensure no invalid Unicode sequences or non-UTF-8 characters were used
- If you used any special characters, verify they are standard UTF-8
- Replace any problematic characters with UTF-8 compatible alternatives

## Customization

This is a generic template. Customize it for your project's specific needs by adding additional sections such as:

- **Framework-Specific Guidelines**: Patterns and conventions for your framework (e.g., Rails, Django, Express)
- **Testing Requirements**: Specific test coverage or testing patterns required
- **Performance Considerations**: When to consider performance implications
- **Security Checklist**: Security review items for sensitive changes
- **Documentation Standards**: When and how to update project documentation

You can add these customizations to this file or create additional instruction files in the `stories/_instructions/` directory.

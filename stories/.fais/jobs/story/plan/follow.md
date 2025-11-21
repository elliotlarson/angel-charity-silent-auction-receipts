# Instructions for Following a Story's Implementation Plan

Find and read the plan file in the same directory as the story that linked to this prompt. The plan file may be named `plan.md` or with a numbered prefix like `02_plan.md`. Execute its implementation steps following the workflow below.

## Character Encoding Requirement

**IMPORTANT**: When generating any content that will be written to files, you MUST use only valid UTF-8 characters. Avoid using:

- Invalid Unicode sequences
- Special characters that may not be UTF-8 compatible
- Unusual symbols or emojis unless explicitly required
- Characters outside the standard UTF-8 range

Stick to standard ASCII and common UTF-8 characters (standard letters, numbers, punctuation, and common symbols).

## Starting the Session

1. **Read the plan**: Find and read the plan file from the story directory to understand the work
2. **Check progress**: Look at the Progress Checklist at the top of the plan file
   - Checked items (- [x]) are completed
   - First unchecked item (- [ ]) is the next task to work on
3. **Review context**: Read the Overview, Key Design Decisions, and the detailed Implementation Steps section for the current step

## Implementation Workflow

**CRITICAL**: Work must proceed step-by-step with explicit approval at each commit point.

### For Each Step:

#### 1. Implement the Step

- Implement all code and tests for the step (implementation and tests go in the SAME commit)
- Follow the "Files to modify" and "Changes" sections in the plan
- Run tests to ensure they pass
- Run linting/formatting tools if specified in the step
- Stage ONLY the files mentioned in that step using `git add`

#### 2. Present for Approval (REQUIRED)

**Every time you complete implementation or make changes, present this approval summary:**

- Summarize what was implemented/changed
- Show which files were staged (`git status`)
- **Present the recommended commit message in a clear code block**
- Ask: "Ready to commit?" or "Ready to commit with this message?"
- **STOP and WAIT for explicit approval**
- Do NOT commit without approval
- Do NOT proceed to the next step without approval

**If the user requests changes or improvements:**

- Implement the requested changes
- Re-stage the modified files
- **Present the commit message AGAIN** with the approval question
- Wait for explicit approval before committing

#### 3. After Approval

- Commit with the approved message
- **Update the progress checklist at the top of the plan file**
- Mark the completed item as checked (- [x])
- Add any notes about implementation decisions made to the plan file if needed
- **THEN** move to the next step

#### 4. When Changes are Requested

- If requested changes deviate from the plan, **update the plan file** to reflect the new approach
- Update affected commit descriptions and checklist items
- Ensure subsequent steps align with the revised approach
- Document why the change was made for future sessions

## Key Requirements

- ✅ Work step-by-step with explicit approval before each commit
- ✅ Update progress checklist in the plan file after each commit
- ✅ Keep tests passing at each commit
- ✅ Stage ONLY the files mentioned in each step
- ✅ Document deviations from the plan in the plan file
- ✅ Implementation and tests must be in the SAME commit
- ❌ Do NOT commit without approval
- ❌ Do NOT proceed to the next step without approval
- ❌ Do NOT batch multiple steps into one commit

## Session Continuity

This plan is designed to work across multiple Claude Code sessions:

- The progress checklist is the source of truth for what's done
- All critical information is in the plan file - don't rely on conversation history
- When resuming, always read the plan file first to understand current state
- Each step includes enough detail for a fresh session to implement it

## Iterating on the Plan

The plan is a living document:

- When reviewing code reveals better approaches, update the plan file accordingly
- Keep the plan synchronized with the actual implementation path
- Add notes about decisions made during implementation
- Ensure the plan file always reflects the current state and approach

## Completion

When all items in the Progress Checklist are checked:

- Verify all tests pass
- Verify the implementation matches the story requirements
- Note any follow-up work or future enhancements in the story directory

## Final UTF-8 Validation

Before completing your work, verify that all content you've written to files uses valid UTF-8 characters:

- Review any markdown files, code files, or text files you've created or modified
- Ensure no invalid Unicode sequences or non-UTF-8 characters were used
- If you used any special characters, verify they are standard UTF-8
- Replace any problematic characters with UTF-8 compatible alternatives

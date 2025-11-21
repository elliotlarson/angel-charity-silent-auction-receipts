# Instructions for Generating Acceptance Testing Instructions

Generate manual acceptance testing instructions in `acceptance.md` by analyzing the story requirements and implementation plan. These instructions should provide high-level test scenarios that QA personnel or developers can follow to verify the functionality works as intended.

## Character Encoding Requirement

**IMPORTANT**: When generating any content that will be written to files, you MUST use only valid UTF-8 characters. Avoid using:

- Invalid Unicode sequences
- Special characters that may not be UTF-8 compatible
- Unusual symbols or emojis unless explicitly required
- Characters outside the standard UTF-8 range

Stick to standard ASCII and common UTF-8 characters (standard letters, numbers, punctuation, and common symbols).

## Process

### 1. Locate and Read the Context Files

First, find the existing acceptance file in the story directory by looking for any file with "acceptance" in its name (e.g., `acceptance.md`, `03_acceptance.md`, `04_acceptance.md`, etc.). You will write your generated content to this existing file.

Then read both context files from the same directory:

- **story.md** (or numbered variant like `01_story.md`) - Contains the feature requirements and user stories
- **plan file** (may be `plan.md` or numbered like `02_plan.md`) - Contains the detailed implementation approach

If either context file is missing or empty, note this in the acceptance file and provide what guidance you can based on available information.

### 2. Identify Testable Functionality

Analyze the story and plan to identify:

- **User-facing features**: Functionality that end users interact with directly
- **UI components**: New or modified interface elements
- **API endpoints**: Backend functionality that can be tested via API calls
- **Developer-only changes**: Internal refactoring or infrastructure that requires technical verification
- **Integration points**: Where this feature interacts with existing functionality

### 3. Prioritize Testing Approaches

Follow this priority order when creating test scenarios:

1. **End-user UI testing** - Test as an end user would, clicking through the interface
2. **API testing** - Direct API calls when UI isn't available yet or for backend-focused features
3. **Developer verification** - Command-line tools, logs, or code inspection for internal changes

### 4. Create Test Scenarios

Structure test scenarios by feature area. For each scenario:

- **Title**: Clear description of what's being tested
- **Preconditions**: Setup required before testing (data, permissions, state)
- **Test Steps**: Numbered steps that are specific and actionable
- **Expected Results**: What should happen at each step or overall
- **Edge Cases**: Boundary conditions, error states, or unusual inputs to test

### 5. Write to the Existing Acceptance File

Write your generated content to the existing acceptance file you found in step 1 (the file with "acceptance" in its name). This file may have a numbered prefix like `03_acceptance.md` or may be simply named `acceptance.md`. Overwrite the existing placeholder content with your comprehensive acceptance testing instructions.

## Output Structure

Your acceptance file should follow this structure:

```markdown
# Acceptance Testing: [Feature Name]

## Overview

Brief description of what's being tested and why.

## Test Environment Setup

Any preparation needed before testing:

- Required data or fixtures
- Configuration settings
- User permissions or roles needed
- Dependencies that must be running

---

## Test Scenario 1: [Scenario Name]

**Priority**: High | Medium | Low

**Test Type**: End-User UI | API | Developer Verification

### Preconditions

- List any setup needed
- Initial system state required

### Test Steps

1. [Action to take]
   - **Expected**: [What should happen]

2. [Next action]
   - **Expected**: [What should happen]

3. Continue...

### Edge Cases to Test

- **[Edge case name]**: [How to test] → [Expected result]
- **[Another edge case]**: [How to test] → [Expected result]

---

## Test Scenario 2: [Next Scenario Name]

[Follow same structure as above]

---

## Regression Testing

Features that should still work after this change:

- [Existing feature to verify]
- [Another feature to check]

## Notes

- Any special considerations for testers
- Known limitations or future work
- Tips for troubleshooting test failures
```

## Writing Guidelines

### Be Specific and Actionable

❌ **Bad**: "Test that the form works"
✅ **Good**: "Fill in the username field with 'testuser', email with 'test@example.com', click Submit, and verify a success message appears"

### Include Concrete Examples

❌ **Bad**: "Enter some invalid data"
✅ **Good**: "Enter an invalid email address like 'notanemail' and verify an error message 'Invalid email format' appears below the field"

### State Expected Results Clearly

❌ **Bad**: "Check that it worked"
✅ **Good**: "Verify the page redirects to /dashboard and displays 'Welcome, testuser' in the header"

### Prioritize Appropriately

- **High**: Core functionality, critical user paths, data integrity
- **Medium**: Important features, common use cases
- **Low**: Edge cases, nice-to-have features, unlikely scenarios

### Balance Detail and Readability

- Provide enough detail that someone unfamiliar with the code can test
- Don't write overly verbose instructions that obscure the key actions
- Group related steps logically

## Handling Different Types of Changes

### UI Features

Focus on user interactions:

- What elements should appear
- What happens when clicked/typed/selected
- Visual feedback and transitions
- Responsive behavior if applicable

### API Features

Include API testing details:

- HTTP method and endpoint
- Request payload structure with examples
- Expected response status and body
- Authentication requirements

### Internal/Infrastructure Changes

Provide developer verification steps:

- Commands to run to verify behavior
- Log messages or metrics to check
- Files or directories to inspect
- Performance or efficiency improvements to measure

### Bug Fixes

Test the specific issue:

- Steps to reproduce the original bug
- Verification that the bug no longer occurs
- Related scenarios that might be affected

## Example

Here's a brief example for a user registration feature:

```markdown
# Acceptance Testing: User Registration

## Overview

Testing the new user registration flow that allows visitors to create accounts via email/password.

## Test Environment Setup

- Ensure the database is running and migrations are applied
- Clear any existing test users with email: test@example.com

---

## Test Scenario 1: Successful Registration

**Priority**: High
**Test Type**: End-User UI

### Preconditions

- User is not logged in
- On the homepage at `/`

### Test Steps

1. Click "Sign Up" button in the navigation
   - **Expected**: Redirects to `/register` with registration form visible

2. Fill in the form:
   - Username: `testuser`
   - Email: `test@example.com`
   - Password: `SecurePass123!`
   - Confirm Password: `SecurePass123!`

3. Click "Create Account" button
   - **Expected**: Success message "Account created! Check your email to verify."
   - **Expected**: Redirects to `/login` page

4. Check email inbox for test@example.com
   - **Expected**: Email received with subject "Verify your account"
   - **Expected**: Email contains verification link

### Edge Cases to Test

- **Duplicate email**: Try registering with an existing email → Error: "Email already in use"
- **Password mismatch**: Different values in password fields → Error: "Passwords don't match"
- **Weak password**: Use "123" → Error: "Password must be at least 8 characters"
```

## Common Pitfalls to Avoid

- ❌ Don't duplicate automated test scenarios - focus on manual verification
- ❌ Don't write tests that require reading code - make them executable by QA
- ❌ Don't skip edge cases - they often reveal important bugs
- ❌ Don't forget to test error states and validation
- ❌ Don't overlook regression testing of existing features

## Final Checks

Before finalizing the acceptance file:

- ✅ All major functionality from the story is covered
- ✅ Test scenarios are clear and actionable
- ✅ Expected results are specific and measurable
- ✅ Both happy path and error cases are included
- ✅ The format is consistent throughout
- ✅ Any technical jargon is explained for QA audience
- ✅ Content was written to the existing acceptance file (with or without numbered prefix)

## Final UTF-8 Validation

Before completing your work, verify that all content you've written to files uses valid UTF-8 characters:

- Review any markdown files, code files, or text files you've created or modified
- Ensure no invalid Unicode sequences or non-UTF-8 characters were used
- If you used any special characters, verify they are standard UTF-8
- Replace any problematic characters with UTF-8 compatible alternatives

# Get GitHub Pull Request

Download and store a GitHub pull request locally using the `gh` CLI command.

## Character Encoding Requirement

**IMPORTANT**: When generating any content that will be written to files, you MUST use only valid
UTF-8 characters. Avoid using:

- Invalid Unicode sequences
- Special characters that may not be UTF-8 compatible
- Unusual symbols or emojis unless explicitly required
- Characters outside the standard UTF-8 range

Stick to standard ASCII and common UTF-8 characters (standard letters, numbers, punctuation, and
common symbols).

## Instructions

1. **Prompt for PR number**: Ask the user for the GitHub pull request number to download.

2. **Create PR directory**: Create a directory named `github_pull_request_<number>` in the story
   directory (the same directory containing the story.md file). If this directory already exists,
   remove it completely and create a fresh one.

3. **Fetch PR data**: Use the
   `gh pr view <number> --json number,title,state,url,body,author,createdAt,baseRefName,headRefName,comments,reviews`
   command to retrieve:
   - PR title
   - PR description/body
   - All review comments on the PR
   - PR metadata (base branch, head branch, author, state, etc.)

   Note: The `--json` flag is required to avoid GraphQL errors related to GitHub's deprecated
   Projects (classic).

4. **Download attachments**: If the PR description or comments contain images or file attachments:
   - Download all images and files from both the PR body AND all comments
   - Save them with descriptive names (e.g., `image_1.png`, `attachment_1.pdf`)
   - Number files sequentially across the entire PR (not per-comment)

5. **Create pull_request.md**: Generate a markdown file named `pull_request.md` inside the PR
   directory with:
   - PR title as the main heading
   - PR metadata (number, author, state, base branch, head branch, created date, URL)
   - PR description/body
   - All review comments in chronological order, clearly formatted with reviewer name and timestamp

6. **Create code.md**: Generate a markdown file named `code.md` inside the PR directory with:
   - Use `gh pr view <number> --json commits --jq '.commits[].oid'` to get all commit SHAs for the
     PR
   - For each commit SHA, run `git log -p -1 <sha>` to get the commit message and full diff
   - Format each commit as a section with:
     - Commit SHA as heading
     - Commit message
     - Full diff showing all changes
   - Include all commits from the PR in chronological order

7. **Update file references**: Replace any GitHub-hosted image URLs or file URLs in the markdown
   files with relative paths to the locally downloaded files.

## Example Output Structure

```
github_pull_request_456/
├── pull_request.md
├── code.md
├── image_1.png
└── diagram.png
```

## Error Handling

- If the PR number doesn't exist, display the error and prompt the user to try again
- If you don't have access to the repository, explain the error and suggest the user authenticate
  with `gh auth login`
- If there are no attachments, simply create the markdown files without downloading any files
- If there are no commits (unlikely but possible), create an empty code.md file with a note
  explaining this

## Final UTF-8 Validation

Before completing your work, verify that all content you've written to files uses valid UTF-8
characters:

- Review any markdown files, code files, or text files you've created or modified
- Ensure no invalid Unicode sequences or non-UTF-8 characters were used
- If you used any special characters, verify they are standard UTF-8
- Replace any problematic characters with UTF-8 compatible alternatives

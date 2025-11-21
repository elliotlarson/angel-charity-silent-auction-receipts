# Get GitHub Issue

Download and store a GitHub issue locally using the `gh` CLI command.

## Character Encoding Requirement

**IMPORTANT**: When generating any content that will be written to files, you MUST use only valid UTF-8 characters. Avoid using:

- Invalid Unicode sequences
- Special characters that may not be UTF-8 compatible
- Unusual symbols or emojis unless explicitly required
- Characters outside the standard UTF-8 range

Stick to standard ASCII and common UTF-8 characters (standard letters, numbers, punctuation, and common symbols).

## Instructions

1. **Prompt for issue number**: Ask the user for the GitHub issue number to download.

2. **Create issue directory**: Create a directory named `github_issue_<number>` in the story directory (the same directory containing the story.md file). If this directory already exists, remove it completely and create a fresh one.

3. **Fetch issue data**: Use the `gh issue view <number> --json number,title,state,url,body,author,createdAt,comments` command to retrieve:
   - Issue title
   - Issue description/body
   - All comments on the issue

   Note: The `--json` flag is required to avoid GraphQL errors related to GitHub's deprecated Projects (classic).

4. **Download attachments**: If the issue description or comments contain images or file attachments:
   - Download all images and files from both the issue body AND all comments
   - Save them with descriptive names (e.g., `image_1.png`, `attachment_1.pdf`)
   - Number files sequentially across the entire issue (not per-comment)

5. **Create issue.md**: Generate a markdown file named `issue.md` inside the issue directory with:
   - Issue title as the main heading
   - Issue metadata (number, author, state, created date)
   - Issue description/body
   - All comments in chronological order, clearly formatted with commenter name and timestamp

6. **Update file references**: Replace any GitHub-hosted image URLs or file URLs in the markdown with relative paths to the locally downloaded files.

## Example Output Structure

```
github_issue_123/
├── issue.md
├── image_1.png
├── image_2.png
└── diagram.pdf
```

## Error Handling

- If the issue number doesn't exist, display the error and prompt the user to try again
- If you don't have access to the repository, explain the error and suggest the user authenticate with `gh auth login`
- If there are no attachments, simply create the issue.md file without downloading any files

## Final UTF-8 Validation

Before completing your work, verify that all content you've written to files uses valid UTF-8 characters:

- Review any markdown files, code files, or text files you've created or modified
- Ensure no invalid Unicode sequences or non-UTF-8 characters were used
- If you used any special characters, verify they are standard UTF-8
- Replace any problematic characters with UTF-8 compatible alternatives

---
name: gitlab-mr-review
description: >
  Review a GitLab merge request: fetch MR (default repo = project name), analyze
  the diff, and optionally post review comments. Use when asked to review an MR,
  do a code review on GitLab, or when the user wants MR feedback. 
  Triggers on: review MR, review merge request, review this MR, code review GitLab, glab mr review.
---
# GitLab Merge Request Review

Perform a code review on a GitLab merge request. Prefer **glab MCP** for fetching MR data; use **glab CLI** when MCP is unavailable.

---

## Repo and MR Resolution

### Default repo

- **Default:** The GitLab project is assumed to be the **same as the current project name** (e.g. workspace or repo directory name).
- If the current directory is a Git repo with a GitLab remote, use that to infer `namespace/project` when possible.

### When repo is missing or wrong

If any of these are true:

- Not in a Git repo, or
- No GitLab remote, or
- The MR to review is in a **different** project,

then **ask the user** for:

- **Repo:** GitLab project path (`namespace/project` or full path), or the repo URL.
- **MR:** Merge request IID (e.g. `42`) or branch name, if not the current branch.

Do not guess the repo; ask once you know the default does not apply or cannot be determined.

---

## Workflow

1. **Resolve repo**
   - Use default (project name / current GitLab remote).
   - If not available or not the target repo, ask user for repo (and MR if needed).
2. **Resolve MR**
   - Prefer the merge request for the **current branch**.
   - If user specified an MR IID or branch, use that.
   - If none can be determined, ask for MR IID or branch.
3. **Fetch MR data**
   - **MCP:** Use glab MCP tools to get MR details and diff (e.g. view MR, get diff).
   - **CLI:** `glab mr view [MR_IID]` and `glab mr diff [MR_IID]` (omit MR_IID when one MR is in context for current branch).
   - Ensure you have the full diff and title/description before reviewing.
4. **Perform the review**
   - Analyze the diff for:
     - Correctness and logic
     - Security and data handling
     - Style, naming, and structure
     - Tests and edge cases
     - Docs and comments where relevant
   - Produce a concise review: summary, list of findings (with file/line or hunk context), and suggestions.
5. **Optional: post as MR comment**
   - **Only after user confirmation.** Do not post to GitLab until the user explicitly agrees.
   - **MCP:** Use the tool to add a comment (e.g. MR note) with the review text.
   - **CLI:** `glab mr note [MR_IID] --message "..."` with the review body (escape or quote appropriately).
6. **Optional: approve MR**
   - **Only if the MR has no items to fix or resolve, Nits and Suggestions should be allowed.** Do not approve or prompt the user to approve the MR if there are items to fix or resolve.
   - **Only after user confirmation.** Do not approve the MR until the user explicitly agrees.
   - **MCP:** Use the tool to approve the MR.
   - **CLI:** `glab mr approve [MR_IID]`

---

## Getting MR data

- **MCP:** Use available glab MCP tools to:
  - List or get the current/specified MR
  - Retrieve the MR diff
- **CLI (from repo with glab auth):**
  - `glab mr view` - view MR for current branch (or `glab mr view <IID>`)
  - `glab mr diff` - diff for current branch MR (or `glab mr diff <IID>`)
  - If repo is different: `glab mr view -R namespace/project <IID>` and `glab mr diff -R namespace/project <IID>`

---

## Review output format

1. **Summary:** 2-4 sentences on what the MR does and overall assessment.
2. **Findings:** Group by severity or category (e.g. "Blocking", "Suggestions", "Nits").
   - For each item: file (and line/hunk if possible), issue, and suggested change or question.
3. **Conclusion:** Approve / approve with comments / request changes (or equivalent), and any follow-up steps.

Keep the review actionable: clear, specific, and tied to the diff.

---

## Checklist

- [ ] Repo resolved (default = project name; else asked user for repo)
- [ ] MR resolved (current branch or user-specified IID/branch)
- [ ] MR details and full diff fetched (MCP or CLI)
- [ ] Review written with summary, findings with context, and conclusion
- [ ] If posting comment: user confirmed; then used MCP or `glab mr note`
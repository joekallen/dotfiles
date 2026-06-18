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
   - **MCP:** Use glab MCP tools to get MR details (title, description, state).
   - **CLI:** `glab mr view [MR_IID]` (omit MR_IID when one MR is in context for current branch).
   - Do **not** fetch the full diff yet.
4. **Check MR state**
   - If the MR state is `merged`, notify the user and ask if they want to continue with the review.
   - If the user declines, stop the workflow.
   - If the user confirms, proceed to fetch the full diff.
5. **Fetch full diff**
   - **MCP:** Use glab MCP tools to get the MR diff.
   - **CLI:** `glab mr diff [MR_IID]` (omit MR_IID when one MR is in context for current branch).
   - If repo is different: `glab mr diff -R namespace/project <IID>`
6. **Perform the review**
   a. **Detect language(s):** Identify the primary language(s) in the diff
      (e.g. Helm/YAML, Go, Python, TypeScript).
   b. **Check for a language-specific review skill:** Look in `<available_skills>`
      for a skill named `mr-review-<language>` (e.g. `mr-review-helm`, `mr-review-go`).
      - If found: load it with the `skill` tool and use its checklist for steps c–f below.
        The language skill's checklist replaces the general one.
      - If not found: use the general checklist in step c.
   c. **General checklist (fallback):** For every changed file, evaluate ALL of
      the following and record a finding for each issue found:

      **Correctness**
      - Null/nil dereferences or missing existence checks
      - Off-by-one errors in loops, slices, or ranges
      - Ignored or swallowed error/return values
      - Incorrect conditionals or inverted logic
      - Unreachable or dead code

      **Security**
      - Hardcoded secrets, tokens, or credentials
      - Injection vectors (SQL, shell, template)
      - Missing or insufficient input validation
      - Insecure defaults or overly permissive settings

      **API / Contracts**
      - Breaking changes to exported interfaces without a version bump
      - Missing or incorrect documentation on exported symbols

      **Tests**
      - Changed logic with no corresponding test coverage
      - Missing edge cases for new behavior
      - Tests that do not assert the right thing

      **Style / Structure**
      - Naming inconsistent with the surrounding codebase
      - Unnecessary complexity or duplication

   d. **Self-verification pass:** After writing all findings, re-read the diff
      from top to bottom and verify every checklist item was evaluated for every
      file. Add any missed findings before proceeding.
   e. **Anchor all findings** to a specific file and line range from the diff.
      Do not include findings that cannot be tied to a specific location.
   f. **No Issues list:** For every changed file that produced zero findings,
      record it in the `No Issues` severity category (see output format).
      Include the file path and the hunk range(s) reviewed (e.g. `@@ -10,20 +10,22 @@`)
      so coverage can be verified against the diff.
7. **Optional: post as MR comment**
   - **Only after user confirmation.** Do not post to GitLab until the user explicitly agrees.
   - **MCP:** Use the tool to add a comment (e.g. MR note) with the review text.
   - **CLI:** `glab mr note [MR_IID] --message "..."` with the review body (escape or quote appropriately).
8. **Optional: approve MR**
   - **Only if the review contains no `Blocking` findings.** Nits and Suggestions do not prevent the approval prompt.
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

1. **Findings:** Group by severity in this order. Every category is always present;
   use `none` if a category has no items:
   - `Blocking` — must be resolved before merge
   - `Suggestions` — recommended improvements
   - `Nits` — minor style or preference items
   - `No Issues` — files with zero findings; list each as `<file> — <hunk range(s)>`.
     If all files have findings, list `none`.
   - For each finding (Blocking/Suggestions/Nits): file, line/hunk range, issue,
     and suggested change. If a category has no items, write `none`.
2. **Summary:** 2-4 sentences on what the MR does and overall assessment.
3. **Conclusion:** Approve / approve with comments / request changes, and any follow-up steps.

Keep the review actionable: clear, specific, and tied to the diff.

---

## Checklist

- [ ] Repo resolved (default = project name; else asked user for repo)
- [ ] MR resolved (current branch or user-specified IID/branch)
- [ ] MR details fetched (MCP or CLI) — state checked before fetching diff
- [ ] If MR is merged: user prompted and confirmed before fetching diff
- [ ] Full diff fetched (MCP or CLI)
- [ ] Review written with summary, findings with context, and conclusion
- [ ] Self-verification pass completed
- [ ] Every changed file appears in either a finding or the `No Issues` category
- [ ] If posting comment: user confirmed; then used MCP or `glab mr note`
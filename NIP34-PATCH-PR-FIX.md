# NIP-34 Patch → PR Fix

**Date:** 2026-02-21
**Status:** ✅ **FIX IMPLEMENTED** (testing in progress)

---

## Problem

When submitting NIP-34 patches (kind:1617) that create PRs, the system was failing with:

```
Forgejo API error (422): {"message":"repository file already exists [path: README.md]"}
```

### Root Cause

1. **Auto-initialized repositories**: Repositories created with `auto_init: true` include a default README.md
2. **Wrong HTTP method**: The `createOrUpdateFile` method was using `POST` for all operations
3. **Missing file existence check**: The code wasn't checking if files already existed before trying to create them

---

## Solution

### 1. Check File Existence (`NIP34Handler.ts`)

Before creating/updating files on a branch, check if they already exist:

```typescript
// Apply each file change via API
for (const file of patchInfo.files) {
  const content = Buffer.from(file.content).toString('base64');

  // Check if file exists on the branch to get its SHA for updates
  const existingFile = await this.forgejo.getFileContent(
    owner,
    repoName,
    file.path,
    patchBranch
  );

  await this.forgejo.createOrUpdateFile({
    owner,
    repo: repoName,
    filepath: file.path,
    content,
    message: commitMessage,
    branch: patchBranch,
    sha: existingFile?.sha, // Include SHA if file exists (for update)
  });
}
```

### 2. Use Correct HTTP Method (`ForgejoClient.ts`)

Use `PUT` for updates (when SHA is provided), `POST` for creates:

```typescript
async createOrUpdateFile(
  options: CreateOrUpdateFileOptions
): Promise<ForgejoFileResponse> {
  const path = `/repos/${options.owner}/${options.repo}/contents/${options.filepath}`;
  const body: Record<string, unknown> = {
    content: options.content,
    message: options.message,
  };

  if (options.branch) {
    body['branch'] = options.branch;
  }
  if (options.sha) {
    body['sha'] = options.sha;
  }

  // Use PUT for updates (when SHA provided), POST for creates
  const method = options.sha ? 'PUT' : 'POST';
  return this.request<ForgejoFileResponse>(method, path, body);
}
```

---

## Testing Flow

### 1. Create Repository

```javascript
const repoEvent = finalizeEvent(
  {
    kind: 30617,
    tags: [
      ['d', `${OWNER}/${REPO_NAME}`],
      ['name', REPO_NAME],
      ['description', 'Test repository'],
    ],
    content: '',
  },
  sk
);
```

### 2. Submit Patch

```javascript
const patchEvent = finalizeEvent(
  {
    kind: 1617,
    tags: [['a', `30617:${pk}:${OWNER}/${REPO_NAME}`]],
    content: gitFormatPatchContent,
  },
  sk
);
```

### 3. Expected Result

- ✅ New branch created (e.g., `patch-f41ddbc4`)
- ✅ Files applied to branch (update if exists, create if new)
- ✅ Pull request created automatically

---

## Forgejo API Reference

### File Operations

**Create File:** `POST /repos/{owner}/{repo}/contents/{filepath}`

```json
{
  "content": "base64_encoded_content",
  "message": "commit message",
  "branch": "branch_name"
}
```

**Update File:** `PUT /repos/{owner}/{repo}/contents/{filepath}`

```json
{
  "content": "base64_encoded_content",
  "message": "commit message",
  "branch": "branch_name",
  "sha": "file_sha_for_update"
}
```

**Get File:** `GET /repos/{owner}/{repo}/contents/{filepath}?ref={branch}`

```json
{
  "content": "base64_encoded_content",
  "sha": "file_sha"
}
```

---

## Commit

```bash
git commit -m "fix(nip34): use PUT for file updates in Forgejo API

- Modified createOrUpdateFile to use PUT when SHA is provided (update)
- Modified handlePatch to check if files exist before creating/updating
- This fixes the 'repository file already exists' error when applying patches

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Commit:** `165824d`

---

## Files Modified

| File                                       | Change                                                |
| ------------------------------------------ | ----------------------------------------------------- |
| `packages/core/src/nip34/NIP34Handler.ts`  | Added file existence check in `handlePatch()`         |
| `packages/core/src/nip34/ForgejoClient.ts` | Changed `createOrUpdateFile()` to use PUT for updates |

---

## Next Steps

- [x] Implement fix
- [x] Commit changes
- [ ] Rebuild Docker container
- [ ] Test patch→PR creation
- [ ] Verify PR is created successfully
- [ ] Document success in NIP34-COMPLETE-TEST-RESULTS.md

---

_Generated: 2026-02-21_
_Status: Fix implemented, testing in progress_

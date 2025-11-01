# Repository Cleanup Instructions

## Overview
This PR contains the security remediation documentation. To complete the cleanup and keep only the main branch, follow these steps:

## Steps to Execute

### 1. Merge This PR to Main
```bash
# Option A: Via GitHub UI (Recommended)
1. Go to the PR page
2. Click "Merge pull request"
3. Choose "Squash and merge" or "Create a merge commit"
4. Confirm the merge

# Option B: Via Command Line
git checkout main
git pull origin main
git merge --no-ff copilot/remove-api-key-and-secure
git push origin main
```

### 2. Delete the Copilot Branch

After merging, delete the branch:

```bash
# Via GitHub UI (Recommended)
1. After merging, GitHub will offer a "Delete branch" button
2. Click it to remove the branch

# Via Command Line
git push origin --delete copilot/remove-api-key-and-secure
git branch -d copilot/remove-api-key-and-secure
```

### 3. Verify Only Main Branch Remains

```bash
# Check local branches
git branch

# Check remote branches
git branch -r

# Should only see main (and possibly HEAD)
```

### 4. CRITICAL: Revoke the Exposed API Key

**DO THIS IMMEDIATELY** - The API key is still exposed in Git history:

1. Go to https://console.cloud.google.com/apis/credentials
2. Find key: `AIzaSyBJ0MT3q-ro7JaXcWsll3C8SF0mbwSIois`
3. DELETE or RESTRICT it
4. Generate a new key if needed
5. Check audit logs for unauthorized usage

### 5. Close the Secret Scanning Alert

After revoking the key:
1. Go to repository Settings → Security → Secret scanning
2. Find Alert #1
3. Click "Close as" → "Revoked"
4. Add comment: "API key revoked on [date], new key generated"

## Final Repository State

After completing these steps:
- ✅ Only `main` branch exists
- ✅ Security documentation is in `main`
- ✅ Exposed API key is revoked
- ✅ Secret scanning alert is closed
- ✅ Current code is secure (uses environment variables)

## Important Notes

- The secret will still exist in Git history (commit c7b27c2)
- To completely remove it, you'd need to rewrite history (see SECURITY_REMEDIATION.md)
- Rewriting history requires force-push and all collaborators must re-clone
- For most cases, revoking the key is sufficient

## Questions?

Refer to SECURITY_REMEDIATION.md for detailed security guidance.

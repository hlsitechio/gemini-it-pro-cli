# Security Remediation Guide

## ⚠️ Critical Security Issue Identified

**Status:** Active  
**Severity:** HIGH  
**Alert:** Secret Scanning Alert #1

## Summary

A Google API key was accidentally committed to the repository history and is publicly accessible.

- **Exposed Secret:** Google API Key `AIzaSyBJ0MT3q-ro7JaXcWsll3C8SF0mbwSIois`
- **Location:** `itprocli.ps1:26` in commit `c7b27c2`
- **Exposure Time:** Since 2025-11-01 04:22:26 UTC
- **Current Status:** Code fixed, but secret remains in Git history

## Current Code Status ✅

The code has been properly secured in commit `b53568a`:
- Hardcoded API key removed
- Now uses environment variable `$env:GEMINI_API_KEY`
- Proper error handling when API key is not set

## Immediate Actions Required

### 1. Revoke the Exposed API Key (URGENT)

**You must revoke this API key immediately to prevent unauthorized access.**

Steps:
1. Go to [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials)
2. Find the API key: `AIzaSyBJ0MT3q-ro7JaXcWsll3C8SF0mbwSIois`
3. Click on the key to view details
4. Click "DELETE" or "Restrict" to revoke access
5. Confirm the deletion

### 2. Generate a New API Key

1. In Google Cloud Console, create a new API key
2. Apply appropriate restrictions:
   - Set application restrictions (HTTP referrers, IP addresses, etc.)
   - Limit to only the APIs you need (e.g., Gemini API)
3. Store the new key securely using environment variables
4. Never commit the new key to version control

### 3. Check for Unauthorized Usage

1. Go to [Google Cloud Console - API Usage](https://console.cloud.google.com/apis/dashboard)
2. Review usage logs for the exposed key
3. Check for:
   - Unusual spike in API calls
   - Requests from unexpected IP addresses or regions
   - API calls after the exposure date (2025-11-01)

### 4. Clean Git History (Optional but Recommended)

To completely remove the secret from Git history, you'll need to rewrite history:

```bash
# WARNING: This requires force-pushing and will affect all repository users

# Method 1: Using git filter-repo (recommended)
pip install git-filter-repo
git filter-repo --path itprocli.ps1 --invert-paths --force
# Then manually recreate itprocli.ps1 with the secure version

# Method 2: Using BFG Repo-Cleaner
# Download from: https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --replace-text passwords.txt
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# After either method:
git push origin --force --all
git push origin --force --tags
```

**Note:** Force-pushing will require all team members to re-clone the repository.

### 5. Update Secret Scanning Alert

After completing steps 1-3:
1. Go to repository Settings → Security → Secret scanning
2. Find alert #1
3. Click "Close as" → "Revoked"
4. Add a comment documenting what was done

## Prevention for Future

### Use Environment Variables
```powershell
# Good ✅
$apiKey = $env:GEMINI_API_KEY

# Bad ❌
$apiKey = "AIzaSy..."
```

### Use .env Files (with .gitignore)
```bash
# .env file (NEVER commit this)
GEMINI_API_KEY=your_actual_key_here

# .gitignore (ALWAYS commit this)
.env
.env.*
*.key
secrets.json
```

### Enable Pre-commit Hooks
Install tools to scan for secrets before committing:
- [git-secrets](https://github.com/awslabs/git-secrets)
- [detect-secrets](https://github.com/Yelp/detect-secrets)
- [gitleaks](https://github.com/gitleaks/gitleaks)

## References

- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning)
- [Google Cloud - Best Practices for API Keys](https://cloud.google.com/docs/authentication/api-keys)
- [OWASP - Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

## Questions?

If you need assistance with any of these steps, please contact your security team or create a support ticket.

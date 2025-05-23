# Git Workflow Setup and Branching Strategy

## Setup
- Initialize a new Git repository with a default branch `main`.
- Create a `develop` branch from `main`.

---

## 1. Feature Branching and Integration

- Create two feature branches in parallel from `develop`:
  - `feature/user-auth`
  - `feature/payment-integration`

### On `feature/user-auth`:
- Add files for user authentication implementation.
- Commit multiple incremental changes, including adding tests.
- Simulate a bug and fix it with a subsequent commit.

### On `feature/payment-integration`:
- Add files related to payment gateway integration.
- Commit changes with well-described messages.
- Modify a configuration file that is also modified on `feature/user-auth` (to cause a conflict later).

### Integration:
- Merge `feature/user-auth` into `develop`.
- Attempt to merge `feature/payment-integration` into `develop`:
  - Resolve conflicts in the configuration file carefully.
  - Ensure both feature changes coexist after the merge.

---

## 2. Release Branching and Bug Fixes

- From `develop`, create a `release/2.0.0` branch.

### On `release/2.0.0`:
- Update version numbers in all relevant files.
- Add release notes summarizing new features and known issues.
- Fix a critical bug found in testing (simulate this by editing an existing file).
- Commit all changes.

### Merging:
- Merge `release/2.0.0` into `main` and tag this commit as `v2.0.0`.
- Also merge `release/2.0.0` back into `develop`.

---

## 3. Hotfix Workflow

- After release, a critical bug is reported in production.
- Create a `hotfix/2.0.1` branch from `main`.
- Implement the hotfix by editing affected files.
- Commit the fix with a clear message.
- Merge `hotfix/2.0.1` back into `main` and tag it as `v2.0.1`.
- Merge the hotfix branch into `develop` as well.

---

## 4. Feature Backporting

- After hotfix, a minor feature from `develop` (e.g., a UI improvement) needs to be backported to the current release.
- Identify the commit(s) related to this feature.
- Cherry-pick those commits onto the `release/2.0.0` branch.
- Test and commit the backported feature.
- Merge the updated `release/2.0.0` into `main` and tag `v2.0.2`.
- Merge back into `develop` as needed.

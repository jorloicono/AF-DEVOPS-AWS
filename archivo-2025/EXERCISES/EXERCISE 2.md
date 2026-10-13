## 1. Setup Branches
- Create a repo with at least three branches:
  - `main`
  - `feature1` (multiple commits)
  - `feature2` (branched off `main`, multiple commits)

---

## 2. Interactive Rebase on `feature1`
- Rebase `feature1` onto `main` interactively:
  - Reorder commits
  - Squash commits
  - Edit commit messages
  - Drop commits if needed

---

## 3. Rebase `feature2` onto Updated `feature1`
- Rebase `feature2` onto `feature1`
- Resolve any merge conflicts manually
- Continue or abort rebase as necessary

---

## 4. Cherry-pick Commits from `feature1` to `main`
- Identify specific commits to cherry-pick
- Cherry-pick commits individually by commit hash
- Cherry-pick a range of commits (`start^..end` syntax)

---

## 5. Cherry-pick Conflict Scenario
- Create conflicting changes on `main` and in a commit on `feature2`
- Cherry-pick the conflicting commit onto `main`
- Resolve conflicts manually
- Continue the cherry-pick process

---

## 6. Cleanup
- Merge rebased `feature1` into `main` (fast-forward if possible)
- Delete feature branches (`feature1` and `feature2`) to tidy up

---

> **Optional:**  
> Ask for help with conflict resolution, advanced interactive rebase commands, or cherry-pick strategies.

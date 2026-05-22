# Git Worktree + Merge Guide

## Current setup

- Main folder: `/Users/rukesh/Documents/projects/alarmo/alarmo` on branch `green-theme`
- Parallel folder: `/Users/rukesh/Documents/projects/alarmo/alarmo-parallel` on branch `feature/parallel-experiment`

## Commit changes in parallel worktree

```bash
cd /Users/rukesh/Documents/projects/alarmo/alarmo-parallel
git add .
git commit -m "your changes"
```

## Merge parallel branch into existing branch

```bash
cd /Users/rukesh/Documents/projects/alarmo/alarmo
git checkout green-theme
git merge feature/parallel-experiment
```

If there are conflicts:

```bash
# resolve conflicts in files
git add <resolved-files>
git commit
```

Push merged branch:

```bash
git push origin green-theme
```

## Optional cleanup after merge

```bash
git worktree remove /Users/rukesh/Documents/projects/alarmo/alarmo-parallel
git branch -d feature/parallel-experiment
git worktree prune
```

## Optional alternative (linear history)

```bash
cd /Users/rukesh/Documents/projects/alarmo/alarmo
git checkout green-theme
git rebase feature/parallel-experiment
```


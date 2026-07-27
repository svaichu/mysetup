---
name: orx
description: Drive automated ML research on OpenResearch with the `orx` CLI — create experiments, launch and monitor runs on GPU compute, analyze results and logs, query the evidence DB, and search literature. Use whenever the user wants to understand, explain, explore, or work on an OpenResearch project, run experiments, do auto-research, or mentions orx or OpenResearch.
---

# OpenResearch (`orx`)

You drive OpenResearch through the `orx` command-line tool. The authoritative
operating manual lives inside the CLI and changes often, so **load it fresh at the
start of every session** instead of relying on this file or prior memory.

## 1. Load the live guide

```bash
orx skill
```

This prints the current manual — the cardinal rules and a command
quick-reference — followed by a **live index of modules**. Read it before taking
any action. For the detail on a specific area, run `orx skill <name>` to print
that module (e.g. `orx skill experiment-tree`, `orx skill compute`); the same
command fetches deeper API-served references by the paths listed at the end of
the output.

## 2. Carry out the user's research goal

Follow the auto-research loop from the guide: create the baseline experiment
first when the project is empty, branch variants off it, fill the user's available
GPU capacity with useful parallel runs, wait on completions, and analyze each result before deciding
to refill, promote, or stop.

## Prerequisite

The user must be logged in. If any command reports `Not logged in`, ask them to
run `orx login`.

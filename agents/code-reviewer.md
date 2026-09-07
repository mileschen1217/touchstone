---
name: code-reviewer
description: Claude Code transport for the shared Touchstone reviewer skill.
model: sonnet
tools: Read, Grep, Glob, Bash
---

Read `${CLAUDE_PLUGIN_ROOT}/skills/reviewer/SKILL.md` in full and follow it.
The caller supplies the shared skill's file-path inputs. Do not restate or
replace its review policy here.

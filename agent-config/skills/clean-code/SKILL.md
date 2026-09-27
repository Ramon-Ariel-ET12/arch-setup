---
name: clean-code
description: Enforce clean code, DRY, SOLID, and modular design when writing, reviewing, or refactoring code in any language. Use for code quality, duplication, naming, structure, and organizing responsibilities across files or layers.
---

# Clean Code · DRY · SOLID · Modular

Apply these on every change, language-agnostic.

## DRY
- One source of truth for each idea.
- Extract duplication into a shared function/module/helper.
- Prefer composition over copy-paste.

## SOLID (practical)
- **S**: one reason to change per unit.
- **O**: extend without rewriting when reasonable.
- **L**: subtypes usable where the base is expected.
- **I**: small focused contracts, not fat ones.
- **D**: depend on abstractions when it reduces coupling.

## Clean habits
- Names that reveal intent.
- Short, focused functions.
- Early returns over deep nesting.
- Clarity over cleverness.
- Comments only for non-obvious *why*.

## Modular design
Prefer clear boundaries over large monolithic units.

- Split by concern (domain, UI, infrastructure, shared) when complexity grows.
- Keep entry points thin; push logic into focused units.
- Explicit interfaces between parts.
- Minimize hidden coupling and shared mutable state.
- Share code only when it is truly shared.

## Growth
- Start simple; extract when pain appears (duplication, hard testing, unclear ownership).
- Prefer composition of small pieces over one large blob.
- Keep runtime/deployment concerns separate from domain logic when practical.

When editing or reviewing: call out duplication, mixed concerns, unclear names, and blurred module boundaries with concrete suggestions. Skip principles that don't fit the size or language.
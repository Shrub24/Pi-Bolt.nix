---
title: Documentation policy
---

# Documentation policy

## Put information where its reader needs it

- **README / getting started:** installation and the shortest complete adoption path.
- **Guides:** tasks, working examples and warnings needed to execute them safely.
- **Reference:** authoritative arguments, defaults, results, constraints and errors.
- **Architecture:** public explanations of build boundaries and trade-offs. Explain internals without promising them as APIs.
- **Contributing:** checks, authoring rules and maintenance procedures.
- **Internal briefs/plans:** working material outside the public content collection and sidebar.

## Reconcile a change

When behaviour or an interface changes, update its reference owner, affected guide and complete example in the same change.
Summarise and link elsewhere instead of maintaining another full explanation. Preserve applicable limitations when moving pages.
Link upstream for general Nix/Pi/Pi-Bolt behaviour; explain our differences locally.

Treat the implementation and observed behaviour as evidence, not an older brief. Verify new claims with source, evaluation or
a focused build. Label illustrative fragments and unverified limits; remove unsupported measurements and stale recommendations.
For non-obvious contracts, link to the owning implementation or focused check. Prefer file/section links over brittle line
numbers; guides need not cite routine Nix conventions.

## Specs and decision records

Public docs describe shipped behaviour. OpenSpec specifications describe intended behaviour; proposals and tasks track pending
changes. When a change uses OpenSpec, reconcile its public docs before marking it delivered.

Keep-the-Why records durable rationale: decisions, rejected alternatives, constraints and workarounds. Consult existing records
before changing a non-obvious choice; confirm new rationale with the owner and link to it rather than duplicating it in a guide.
Use the repository's existing spec/decision locations when present. Routine prose corrections need no new spec or decision record.

## Author and validate

Use ordinary Markdown with matching frontmatter `title` and source H1, relative `.md` links, and fenced code. The renderer
adapts these for the site. Prefer short sections, concrete behaviour and examples over generic introductions. Use complete
example files when a recipe needs multiple moving parts; keep fragments short and name their assumed bindings.

For each change:

1. Build `.#docs`; resolve internal link/anchor failures and inspect navigation.
2. Evaluate changed complete Nix examples using `docs-examples`, and run focused behavioural checks when the claim needs them.
3. Check representative Markdown on GitHub as well as generated pages. Essential instructions must not depend on tabs or components.
4. Recheck inbound links before moving/removing a public page; retain a useful navigation page for old shared URLs where needed.

The published site describes `main`; revision-specific docs live with each commit. Keep direct Node dependencies exact and
commit `docs/package-lock.json` updates. Use `npm install --ignore-scripts` when refreshing the local install.

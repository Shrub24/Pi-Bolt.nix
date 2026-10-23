---
title: Development
---

# Development

## Check the package

From the repository root:

```sh
nix fmt -- --ci
nix flake check --no-build --all-systems
nix flake check
```

The last command builds checks for the current system. CI builds every declared check on x86_64 and aarch64 Linux. For a focused
change, build its named check instead; for example `nix build .#checks.x86_64-linux.settings`.

New files must be tracked for a Git-backed flake to see them. Keep unrelated changes out of a contribution.

## Work on the documentation

```sh
cd docs
npm ci --ignore-scripts
npm run dev
```

Open the development server's `/Pi-Bolt.nix/` URL. Local search is generated during production builds, not the development
server. Validate the complete site with:

```sh
nix build .#docs
```

The output contains static files, including the local search index. This build needs no Pi-Bolt executable and runs the
rendered-page link, anchor and heading checks. The separate `docs-examples` check evaluates the complete Nix examples without
building their payloads.

For local iteration after installation: `npm run build && npm run check` from `docs/`. A successful renderer build does not
establish that a Nix example evaluates or that its runtime behaviour is correct.

The site uses stock Starlight. Canonical Markdown remains directly under `docs/`; a content loader selects public pages. A
small transform removes the source H1 (Starlight supplies it from frontmatter) and converts relative `.md` links to site URLs.
Keep both the source files and rendered site readable. The custom `404.md` entry is marked draft to avoid a duplicate
catch-all route; Starlight's dedicated error route still renders it.

Hosting is separate from this build. No deployment workflow or repository Pages setting is enabled by this change.

Before changing prose, examples, interfaces or site configuration, follow the [documentation policy](documentation.md).

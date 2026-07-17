# Stories

Work-in-flight for collabornet. Each story is a **delta** — a change we're making and
why. Durable facts about the end state belong in [../README.md](../README.md) (the living
spec). When a story ships, fold any lasting truth up into that README, then move the story
to [done/](done/).

## Conventions

- **IDs are global across the whole SPNC repo**: `SPNC-0001`, `SPNC-0002`, ...
  Find the next number with: `rg '^id: SPNC-' -g '**/stories/**'`
- **Filename**: `SPNC-NNNN-kebab-slug.md` (zero-padded). The human title lives in frontmatter.
- **Status lives in frontmatter** (`todo | doing | blocked | done | dropped`) — that is the
  source of truth.
- **Active stories live flat here.** When `status: done`, move the file into `done/` to
  declutter the active set. That move is the only file relocation in a story's life.
- **Cross-reference other stories by ID** (`related: [SPNC-0002]`), never by path, so the
  `done/` move never breaks links.
- [STORIES.md](STORIES.md) is a convenience board; frontmatter wins if they disagree.

## New story

Copy [`_template.md`](_template.md) to `SPNC-NNNN.slug.md` and fill it in.

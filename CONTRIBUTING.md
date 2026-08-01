# Contributing to zstack

zstack accepts original, portable Agent Skills for independent developers.
Contributions should make a recurring solo-builder workflow more reliable, not
copy a private prompt dump or vendor another skill pack.

## Before opening a change

1. Read [AGENTS.md](./AGENTS.md) and
   [docs/authoring.md](./docs/authoring.md).
2. Confirm the workflow is useful more than once to an independent developer.
3. Search the catalog for overlap; improve an existing skill when that produces
   a clearer user experience than adding another command.

## Add a skill

```bash
./scripts/new-skill.sh z-my-workflow product
# edit skills/z-my-workflow/SKILL.md
# review the auto-created draft in catalog.yaml
# add three behavioral + two routing evals, then set status: active
./scripts/test.sh
./scripts/setup.sh
```

Keep frontmatter to exactly `name` and `description`. The directory,
frontmatter name, and portable skill id must match and use the `z-` prefix.
Link every bundled reference
directly from `SKILL.md` with instructions for when to read it. Replace every
scaffold and catalog placeholder before validation; active skills require at
least three cases in `evals/cases.yaml` (one `happy-path`, plus one `edge` or
`adversarial`) and two in `evals/routing.yaml`. Catalog tags are unique
kebab-case values and must include the `indie` audience tag. Add a `## Contents`
section near the top of any reference longer than 100 lines. Keep trigger
guidance in the frontmatter description instead of repeating `When to use` in
the body. Active skills also require a directly linked quality bar and the
[evidence handoff contract](./docs/evidence-handoff.md) in their primary output.

## Quality gates

The validation scripts require Bash, Git, and Ruby 2.6+. ShellCheck is required
when Bash changes; CI also runs actionlint through Go.

Run before opening a pull request:

```bash
bash -n scripts/*.sh scripts/lib/*.sh
shellcheck scripts/*.sh scripts/lib/*.sh  # when Bash changed
for script in scripts/*.rb scripts/lib/*.rb; do ruby -c "$script"; done
ruby scripts/generate-evidence-manifests.rb --check
ruby scripts/report-evidence-coverage.rb --require-current-complete-pass
ruby scripts/report-evidence-coverage.rb \
  --require-current-complete-pass-host codex \
  --require-current-complete-pass-host grok
ruby scripts/report-evidence-coverage.rb \
  --suite routing \
  --require-current-complete-pass-host codex \
  --require-current-complete-pass-host grok
./scripts/test.sh
./scripts/doctor.sh
git diff --check
```

The evidence commands are intentionally current-source gates. They fail after
a skill-byte or registered-case change until reviewed reruns are published, and
they may also expose a documented host-authentication gap. Do not replace them
with the historical `--require-complete-pass*` variants to make a pull request
green; inspect the coverage report and preserve the limitation instead.

Also invoke a changed skill in at least one supported host. In the pull request,
include the prompt used, the behavior observed, and any environment limitation.
Use [docs/evaluation.md](./docs/evaluation.md) when adding or running behavioral
or routing regression cases. The Codex, Claude, and Grok behavioral runners
preserve exact skill snapshots and raw responses but deliberately leave semantic
grades to review; routing runners grade only the exact registered selection and
preserve the same private provenance boundary.

## Pull request scope

- Keep one logical change per pull request.
- Explain what changed, why it helps a solo developer, and how it was verified.
- Do not include secrets, customer data, private URLs, or machine-local paths.
- Do not add generated host-specific copies of a skill.
- Do not vendor third-party skills. Link to external tools in documentation when
  useful.

By contributing, you agree that your contribution is licensed under this
repository's [MIT License](./LICENSE).

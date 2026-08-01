# Evidence handoff contract

zstack skills may run independently or as a product-learning chain. A handoff
must preserve what the evidence can and cannot prove; repetition in a later
artifact never upgrades confidence.

## Evidence classes

| Class | Examples | Does not prove by itself |
|-------|----------|--------------------------|
| Primary behavior | Interview stories, current workflow, prior switching | Market scale, payment, retention |
| Observed experiment | Attributed signup, reply, preorder, product event | Anything the event did not measure |
| Secondary public | Community posts, reviews, competitor pricing | Direct customer intent or payment |
| Search signal | SERP shape, query language, GSC observation | Product-market fit or retention |
| Assumption | Founder input, inferred constraint, planned target | Evidence until tested |

Keep the narrowest accurate class. For example, a provider-confirmed signup is
an observed signup—not payment—and a quoted competitor price is a secondary
price signal—not willingness to pay for this product.
List only classes supported by supplied inputs or actual results in the current
artifact. A planned interview, experiment, SERP check, or payment ask belongs
in `Next validation`; it does not make its future evidence class current.
The class cell is never empty. If the current artifact has only missing,
invalid, or unverified inputs, use `assumption` and explain the limitation in
`Supported claims`, `Still unproven`, and `Source anchors`.

## Required output block

Decision-producing skills include exactly one two-column table headed
`Field | Value` in their primary output. Its seven first-column labels are
literal protocol tokens: keep their spelling, order, punctuation, and plain
text unchanged, and do not add a third status, class, metric, or detail column.

| Field | Value |
|-------|-------|
| Current decision | The present proceed / reshape / hold choice |
| Evidence classes | Applicable canonical class names only |
| Supported claims | Only conclusions the cited evidence warrants |
| Still unproven | Material claims the workflow did not establish |
| Contradictions / exclusions | Counterevidence, invalid signals, and killed scope |
| Source anchors | URLs, note ids, artifact paths, or dated metric slices |
| Next validation | One action, owner, and observable success/fail signal |

For a plan written before results exist, use `TBD after test` for
result-dependent rows. Do not copy the hypothesis into supported claims.

## Authoring rule

Keep the block inside each skill's own output template so symlink-installed
skills remain self-contained. A shared explanation may live here, but runtime
instructions must not depend on this repository-relative document being
available from an installed skill root.

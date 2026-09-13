# Statistics in depth

Every test the project implements, why it was chosen, how it is validated, and — the part that
matters most here — what the study design cannot answer no matter how the code is written.

All of it lives in `compare_te_cyp_exposure 1 1.py:107-452` and is imported by the other two
comparison scripts. **There is no scipy.** Everything is built from `math.comb`,
`fractions.Fraction` and `statistics.NormalDist`.

---

## 1. Why implemented from scratch

The obvious objection is that `scipy.stats` has all of these and is better tested.

The reason it isn't used is visible in the archive rather than the code: this project's scripts
were passed between machines as zip files over OneDrive
([`OCR docs/04`](../../OCR%20docs/04-atallah-lab-spring-2026-log.md)). Code that runs on
`python3` and nothing else runs wherever it lands. The same reasoning produced the hand-rolled
FASTA index in `build_tfbs_te_gff.py` instead of `pyfaidx`.

The trade is real, and the code answers it the right way: every implementation is
**cross-validated in-process against a second, independently written implementation** —
see §5.

---

## 2. The unit of observation

This is the single most consequential choice in the analysis, and it is made before any test
runs.

**Every individual Cyp gene, pooled across all species, is one observation.** A species
contributing 90 genes contributes 90 rows; one contributing 40 contributes 40.

The alternative — one observation per species — is not viable here, and the code says why in
`bootstrap_species_cluster_ci`'s docstring (`:694-723`):

> with only 5 species split some way into two groups, an exact species-level test has at most
> C(5,3)=10 possible group assignments, so the smallest p-value it could ever produce is
> 1/10 = 0.10 — it can never clear a conventional 0.05 threshold no matter how large the true
> effect is.

That is a hard combinatorial ceiling, not a power problem you can fix with better statistics.
So the pooled test is used for power, and its cost is stated openly: **pseudoreplication.**
Genes within one species share a genome, a phylogeny and an assembly, and are not independent.

Both facts are printed in every generated report. Neither should be removed.

---

## 3. The two pre-registered tests

`run_pooled_tests()` (`:664-692`) builds the pooled gene table and runs both.

### Fisher's exact test — does TE *presence* track exposure?

A 2×2 table of `exposure group (high/low)` × `gene has ≥1 TE (yes/no)`, two-tailed.

`fisher_exact_two_tailed()` (`:107-136`) sums hypergeometric probabilities directly:

```python
def hyper_prob(x):
    return (comb(row1, x) * comb(row2, col1 - x)) / comb(n, col1)
```

then totals every table at least as extreme as the observed one:

```python
if p <= observed_p * (1 + 1e-9):
    total_p += p
```

The `1 + 1e-9` fudge is the detail that makes this correct. The two-tailed Fisher convention
includes tables whose probability *equals* the observed one, and floating-point division makes
exact equality unreliable — without the tolerance, a table that should be included is
occasionally dropped and the p-value comes out too small.

### Mann-Whitney U — does TE *burden* differ?

`mann_whitney_u_test()` (`:192-244`). Normal approximation, two-sided, with:

- **average ranks for ties.** Essential here: per-gene TE counts are small integers with huge
  numbers of ties, especially the zeros.
- **tie correction in the variance**, via `tie_sum = Σ(t³ − t)`. Without it, the standard
  deviation is overstated and the test becomes conservative — exactly the wrong direction for a
  study already short on power.
- **a continuity correction** of ±0.5 applied toward the mean.

Presence/absence and burden are genuinely different questions — a species could have TEs near
the same number of genes but many more per gene — which is why both are reported rather than
one standing in for the other.

### Also computed, deliberately secondary

`chi_square_2x2()` (`:163-190`) and `welch_t_test()` (`:304-346`) are computed and reported
alongside, as familiar cross-checks. Neither is the pre-registered test: chi-square is an
approximation to the Fisher test already being run exactly, and Welch's t-test assumes roughly
normal data, which per-gene TE counts are not.

Welch's needs the t-distribution CDF, hence `regularized_incomplete_beta()` (`:284-302`) and
`_betacf()` (`:246-282`) — Lentz's continued-fraction algorithm, pure stdlib.

---

## 4. The species-cluster bootstrap

`bootstrap_species_cluster_ci()` (`:694-782`). This is the most thoughtful part of the
analysis, and the part most likely to be discarded by someone tidying up. It should not be.

It resamples **whole species** with replacement, separately within each exposure group, and
recomputes the group means each time. Species therefore remains the unit of replication — the
statistically honest choice — while producing as many resamples as you like rather than being
capped at the ten distinct assignments an exact species-level test allows.

Defaults: `n_resamples=10000`, `seed=12345` (so runs are reproducible), `ci=0.95`.

It returns percentile confidence intervals for both the **difference** and the **ratio** of
mean TE-per-gene between groups, plus `prob_high_greater`: the fraction of resamples in which
the high-exposure mean exceeded the low-exposure mean.

> `prob_high_greater` is a **directional confidence statement, not a p-value.** The docstring
> says so explicitly. Reporting it as significance would be wrong.

This is the right shape for the question: with five species you cannot get a defensible
significance verdict, but you can get a defensible *effect size with uncertainty attached*.

---

## 5. Validation

`validate_stats()` (`:373-452`) runs automatically at the start of every normal run — it takes
milliseconds — and is the whole job of `--self-test`.

Each implementation is checked against a **second, differently coded path**:

| Test | Cross-check |
|---|---|
| Fisher's exact | `_fisher_exact_via_fractions()` (`:138-161`) — identical algorithm in exact `Fraction` arithmetic, no float division. Plus the classic R reference `fisher.test(matrix(c(3,1,1,3),2,2)) = 0.4857143` |
| Mann-Whitney U | behavioural: identical distributions → p ≈ 1.0; fully separated groups → p < 0.05 |
| Incomplete beta | `I_x(1,1) == x` (Beta(1,1) is uniform) and `I_0.5(a,a) == 0.5` (symmetry) |
| Welch's t-test | `_t_test_p_via_integration()` (`:356-371`) — numerically integrates the t PDF over 20,000 steps instead of using the closed form |

Running it on the committed code (after renaming the file so it imports):

```
    table=(3,1,1,3) float=0.4857142857 fraction=0.4857142857 OK
    R reference check (3,1,1,3)=0.4857143: OK
    identical distributions: U=50.0 p=1.000000 OK
    fully separated groups:  U=0.0 p=0.012186 OK
    t=3.8703 df=9.02 p(betainc)=0.00377006 p(integration)=0.00377006 OK
[self-test] ALL CHECKS PASSED
```

The failure message is `SOME CHECKS FAILED - DO NOT TRUST RESULTS`, which is the correct tone.

**Run `--self-test` once on any new machine.** It is the cheapest possible check that
stdlib-only numerics behave identically on that platform.

---

## 6. What this design cannot answer

Worth being blunt about, because no amount of code quality changes any of it.

**Significance is out of reach at the species level.** Five species gives at most ten group
assignments and a floor of p = 0.10. If the pooled tests read "inconclusive", the most likely
explanation is the number of species, not the absence of an effect.

**The pooled tests are pseudoreplicated.** They will happily return a small p-value driven by
one unusual species with many Cyp genes. The bootstrap exists precisely to show when that has
happened — a wide or zero-straddling CI next to a small pooled p is the signature.

**Confounds are not modelled at all.** Exposure group is the only predictor. Genome assembly
quality, phylogenetic relatedness, genome size and annotation completeness all plausibly track
TE counts, and none of them enter the analysis. With five species there is no realistic way to
control for them — but "not controlled" is different from "not a problem".

**The input measures the wrong thing, partly.** About 69% of what these tests count as TEs are
simple repeats and low-complexity regions, because nothing upstream filters on repeat class. If
that fraction varies systematically between the groups, it is bias rather than noise. See
[`../pipeline/detailed/04-gaps-and-provenance.md`](../pipeline/detailed/04-gaps-and-provenance.md).

**Multiple comparisons are not adjusted.** Three scripts run the same two tests on three nested
gene sets, and `--alpha` is applied independently in each. If all three reports are read
together, treat that accordingly.

---

## 7. If you extend this

- **Keep the caveats in the generated reports.** They are the mechanism by which a limitation
  reaches the person reading the numbers.
- **Keep `validate_stats()` running on every invocation**, not just under `--self-test`. It is
  what stops a future edit silently breaking a p-value.
- **Adding species is worth more than any statistical refinement.** The binding constraint is
  C(n, k), and only more species moves it.
- **Filtering repeat class would change every number in every report.** Do it deliberately,
  record when it changed, and do not compare filtered results against unfiltered ones.

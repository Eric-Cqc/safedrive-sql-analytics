# SafeDrive SQL Analytics · 研究账本

A fictional designated-driver coursework database with eleven entities and ten traceable analytical questions. All 33 orders are synthetic. Eighteen deliberate counterexamples test time, payment, rating, distance and denominator contracts.

This extension adds a Chinese interactive reader, an independent Python oracle, a guarded MySQL verifier and preserved legacy TSVs. **The tables shown in the reader are Python-derived expected results, not live SQL output. MySQL engine execution and trigger enforcement remain unverified.** The original October 3, 2026 handoff recorded an unavailable MySQL socket and a browser-preview restriction; those are historical environment observations, not a claim about the current machine. Desktop/phone browser behavior has not been revalidated in this publication review.

## Browser verification for this public copy

On 2026-10-18, a local HTTP browser check exercised reporting-preset changes, row evidence, conclusion saving and reload recovery, CSV download, and switching to Q02. This is a limited desktop workflow check, not full browser/mobile coverage or MySQL validation. Historical browser-not-verified statuses in `evidence/` describe the original delivery.

## Read and explore

Open `web/reader.html` in an ordinary browser. It is self-contained and does not install dependencies or connect to a database. Keep the folder alongside it for original fixture/evidence downloads. See [USER_GUIDE.md](USER_GUIDE.md).

Choose a business question and one of seven complete reporting presets. Inspect rows, follow order IDs into event/payment/rating evidence, compare with the fixed convention, examine the exact SQL, export expected CSV/SQL, and save a conclusion with its cited row. Changing the reporting context keeps previous notes as history and maintains drafts by context. Browser persistence/download behavior is implemented but has not been exercised here.

## Question contracts

| Query | Question | Unit and key safeguard |
| --- | --- | --- |
| q01 | High-severity incident share by customer | Affected distinct orders / completed orders; multiple events do not inflate denominator |
| q02 | Driver service cohorts versus cash windows | Completion clock, settlement/refund clocks; one successful assignment; measured km with missing coverage |
| q03 | Frequent custody routes by partner | Distinct completed orders; custody episodes separately; stable tie order |
| q04 | Late starts and nearby assignments | Scheduled start, strict grace; time proximity is not causation |
| q05 | Current versus as-of ratings | Current summary/recomputed values; future ratings excluded from as-of mean |
| q06 | Current VIP customers' completed orders | No historical VIP inference; payment state and net amount at as-of |
| q07 | Ratings by service type | Mean plus review coverage; NULL is unknown, not zero stars |
| q08 | Repeat positive-net settled purchases | Full refunds excluded; repeat orders distinct from vehicle reuse |
| q09 | Fleet by brand and model | Registration clock; zero-vehicle models retained |
| q10 | Overdue unsettled completed services | Seven-day lower bound inclusive; strictly older than 24h; missing payment distinguished |

The default clock is `2025-11-15 12:00:00`, Asia/Hong_Kong wall time (`+08:00` in SQL). Money is CNY; distance is odometer km. The fixture permits one settlement and at most one refund event per order. Current membership tier has no historical timeline.

## Constraint extension

See [CONSTRAINTS.md](CONSTRAINTS.md) for completed-service and settlement/refund immutability, cross-table event-time rules, 32 new pure-data mutation cases and unexecuted SQL rollback probes. The 33-order fixture and original 18 analytical boundaries remain unchanged. These are declared coursework contracts, not production accounting guarantees.

## Verification on October 18, 2026

- 18 Python unit tests pass, including 18 boundary cases, empty result/header handling, reference relationships, CHECK field-reference lint, database identifier rejection, and a mocked existing-schema refusal before any CREATE.
- Seven presets / 70 result tables agree with the current independent Python oracle; default oracle results still match the preserved prior oracle.
- JavaScript syntax and the public artifact audit pass. The ten expected TSV files match the independent Python oracle.
- Before preparing this publication, all 65 copied files matched their source; all 34 source hashes in the historical verification record and all 64 entries in the historical delivery manifest matched.
- The original `evidence/` records are preserved unchanged. They describe the original package and its historical checks, not the fingerprint of this edited publication. [PUBLICATION_MANIFEST.json](PUBLICATION_MANIFEST.json) records the publication files and SHA-256 hashes, excluding itself.
- Corrected a static DDL defect: Payment accidentally referenced ParkingCustody fields in a CHECK clause. The appropriate custody constraint remains on ParkingCustody. Real engine acceptance still requires execution.
- Case 33 is an unrated **service** assigned to a driver who already has ratings; the reader explains the inaccurate old shorthand rather than pretending the driver has no ratings.

These checks do not establish MySQL compatibility, trigger behavior, rollback, concurrency, production use, browser usability or learning gains.

## Reproduce Python/static artifacts

Use an existing Python runtime; these scripts use the standard library only. No dependency installation or large download is needed.

```sh
PYTHONDONTWRITEBYTECODE=1 OMP_NUM_THREADS=2 OPENBLAS_NUM_THREADS=2 python3 scripts/build_reader.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
node --check web/app.js
python3 scripts/verify_expected_results.py --candidate-dir evidence/python-expected
python3 scripts/audit_public_tree.py
```

`evidence/python-expected/` contains Python-derived expected TSVs. `evidence/legacy-results/` contains unchanged original snapshots. `results/` is reserved for future successful live MySQL outputs and currently does not exist.

## Future real MySQL compatibility check

Only when an already running trusted local MySQL server and an authorized local socket are available:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 scripts/verify_mysql.py \
  --database safedrive_candidate_unique_test \
  --mysql-socket /path/to/existing/mysql.sock \
  --mysql-user root
```

The name must match `safedrive_[a-z0-9_]{1,40}_test`. The verifier checks both fresh candidate and repeat schema names before mutation and refuses any existing schema. It never uses CREATE IF NOT EXISTS or drops databases. A race fails at CREATE. No default credential files or login paths are read, no remote TCP target is accepted, and no server is installed or started.

Two separate fresh synthetic schemas receive the SQL, trigger replacement, ten queries, six parameter probes and transactional assertions. Outputs are published only after the entire cycle passes oracle/idempotency checks. Fresh test schemas remain for inspection; this project does not delete them. Exit2 is BLOCKED-DB,3 is BLOCKED-DISK,64 is refused target,1 is a failure,0 is full verification success. A CLI exit alone is not a compatibility statement: inspect `evidence/mysql-verification.json` and source/result hashes.

Optional baseline reproduction is supported only in additional fresh candidate schemas; it was not requested or run in this continuation. Do not point any manual DDL or verifier at an existing business database. No database was created or changed in this task.

## Provenance and limitations

Original task-19 files remain unchanged; `evidence/source-baseline.json` records their hashes. This directory is a separate candidate. There are no real users, payments, dispatches, operating results or production security/concurrency evidence. The small selected fixture is designed for counterexamples, not driver quality or business-rate estimation. SQL supports the coursework model and is not a complete production service.

MIT; see [LICENSE](LICENSE).

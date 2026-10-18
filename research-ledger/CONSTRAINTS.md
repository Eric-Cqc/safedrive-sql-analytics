# Candidate constraint extension

All records and32 mutation cases are synthetic. These rules describe this coursework model, not a production settlement, dispatch or audit system. Original37 files and the33-order fixture remain unchanged at their original locations.

## Added rules

1. A nonempty Driver rating summary requires a non-NULL mean equal to its count/sum arithmetic. SQL CHECK treats UNKNOWN differently from FALSE; the explicit non-NULL condition closes that gap. Empty summaries retain NULL, not zero stars.
2. A successful Assignment must reference a completed order with the same completion timestamp. Once successful, its identity, driver, order and event timestamps cannot change, and it cannot be deleted. Valid odometer corrections, including both values becoming unknown, remain allowed.
3. An assigned order retains its identity, request time and scheduled start. A completed order retains the completion fact tied to the successful service. A request cannot move after a recorded settlement.
4. Payment identity is immutable. Once settlement time/amount or refund time/amount is recorded, those fields cannot be rewritten or erased. Valid pending→paid and paid→partial/full refund transitions remain allowed. The model still permits only one settlement and at most one refund per order; additional corrections require a different event-ledger design.
5. Parking custody and reimbursement submission must occur at or after assignment time. Their assignment identity cannot be changed. Open custody checkout remains valid. The parent assignment cannot move after an already recorded dependent event.

Future-dated completion, payment, refund and rating records remain permitted in the deliberately constructed fixture. As-of queries decide when they become known; constraints do not erase those counterexamples. Ratings can still be edited/deleted with summary maintenance; this schema has no historical version store for rating corrections or descriptive attributes.

## Verification identity

`scripts/constraint_contract.py` is an independent pure-data expected-predicate checker. It does not execute or emulate MySQL. `data/constraint-cases.json` contains32 named mutations and positive controls; the fixture is checked without modifying it. Tests also verify finite amounts, NULL/zero distinctions, trigger declaration/drop-name consistency and NEW/OLD field/event scopes. That lint is not a complete SQL parser.

`sql/30_assertions.sql` now contains11 additional rejection probes and5 positive SQL statements. They run only through the guarded verifier in fresh synthetic candidate schemas and roll back. A final assertion checks that payment facts were restored. **These SQL probes and trigger enforcement passed on MySQL 9.7.1 on 2026-10-18 in two fresh synthetic schemas.**

The MySQL verifier performs synthetic-fixture/CHECK-reference preflight before any connection, refuses pre-existing schema names and stops before mutation below5GiB. The October 18 validation used the already-installed MySQL binary with a new task-local data directory and networking disabled; existing server data was untouched.

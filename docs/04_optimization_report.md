# Phase 4 – Query Optimization Report

**Project:** MakeMyTrip Travel Booking Database  
**Team:** T0051  
**Database:** `mmt_baseline`  
**Schema:** `mmt`  
**PostgreSQL:** 18.6  
**Dataset:** 144,792 bookings  
**Benchmark:** 5 runs per query; average execution time reported  
**Date:** 19 November 2026

---

## 1. Optimization Summary

Phase 4 focuses on reducing query execution time through appropriate indexes and query rewrites while preserving the results of rewritten queries. The original workload contains 25 read queries and 5 write queries.

The sum of the average execution times for all 30 queries decreased from **2,824.602 ms** to **281.797 ms**, representing an overall reduction of **90.02%**.

| Workload | Baseline (ms) | Optimized (ms) | Improvement |
|---|---:|---:|---:|
| Read queries (R01–R25) | 2,789.176 | 274.167 | 90.17% |
| Write queries (W01–W05) | 35.426 | 7.630 | 78.46% |
| **All 30 queries** | **2,824.602** | **281.797** | **90.02%** |

These values are the sum of the individual query averages. They are not the wall-clock time of one complete workload execution.

Improvement is calculated using:

`((Baseline - Optimized) / Baseline) × 100`

A positive percentage indicates faster execution. A negative percentage indicates slower execution.

## 2. Optimization Results – All 30 Queries

The following table compares the baseline and optimized benchmark results. Scan information is taken from the recorded benchmark plan summaries.

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|---|
| R01 | 13.844 | Sequential scans on flights and flight_bookings; date function prevents direct timestamp index filtering. | Half-open departure timestamp range; route/departure and flight-booking indexes. | 0.243 | 98.24% | Yes – EXCEPT ALL passed |
| R02 | 2.493 | Sequential scan on flights for route and date filtering. | Half-open July timestamp range and route/departure index. | 0.176 | 92.94% | Yes – EXCEPT ALL passed |
| R03 | 1.204 | Sequential scan on hotels for city, rating and amenities filtering. | Hotel city/rating index. | 0.495 | 58.89% | SQL unchanged |
| R04 | 7.751 | Sequential scan on hotel_bookings for room availability and date overlap. | Composite room-type/check-in covering index. | 0.266 | 96.57% | SQL unchanged |
| R05 | 14.428 | Sequential scan on bookings for customer and status filtering. | Covering customer/status index. | 0.194 | 98.66% | SQL unchanged |
| R06 | 0.125 | Existing unique booking-reference index already provides efficient lookup. | Retained existing unique index; no query rewrite. | 0.104 | 16.80% | SQL unchanged |
| R07 | 8.679 | Sequential scan on flight_bookings for flight manifest lookup. | Index on flight_bookings(flight_id) with included columns. | 0.352 | 95.94% | SQL unchanged |
| R08 | 14.867 | Sequential scans on flights and flight_bookings for July flight aggregation. | Flight status/departure and flight-booking indexes. | 3.625 | 75.62% | SQL unchanged |
| R09 | 26.647 | Sequential scans on bookings, flight_bookings and flights; aggregation remains expensive. | Covering booked_at index narrows the booking-date range. | 18.041 | 32.30% | SQL unchanged |
| R10 | 1.299 | Sequential scan on flights for delayed status filtering. | Composite status/departure index. | 0.132 | 89.84% | SQL unchanged |
| R11 | 11.955 | Sequential scan on bookings for pending-payment filtering and ordering. | Composite status/booked_at covering index. | 0.163 | 98.64% | SQL unchanged |
| R12 | 48.261 | Sequential scan on bookings; EXTRACT(YEAR) prevents a direct timestamp range scan. | Replaced year extraction with a half-open 2026 timestamp range. | 24.335 | 49.58% | Yes – EXCEPT ALL passed |
| R13 | 24.144 | Original NOT IN query gives an incorrect result when the subquery contains NULL. | Replaced NOT IN with NULL-safe NOT EXISTS. | 16.059 | 33.49% | Correctness fix; see Section 4 |
| R14 | 54.584 | Sequential scans across bookings, flight_bookings, flights and airlines; broad aggregation. | No major rewrite; aggregation still requires processing many rows. | 53.652 | 1.71% | SQL unchanged |
| R15 | 28.180 | Sequential scans and multi-table aggregation for room-nights calculation. | Check-out covering index supports stay-overlap filtering. | 27.119 | 3.77% | SQL unchanged |
| R16 | 118.169 | Original query aggregates bookings, customers, flight_bookings, flights and hotel_bookings. | Precomputed summary using mv_lead_days_by_tier. | 0.046 | 99.96% | Yes – EXCEPT ALL passed |
| R17 | 32.399 | Sequential scan on bookings for completed trips and customer aggregation. | Status/booked_at index. | 26.903 | 16.96% | SQL unchanged |
| R18 | 5.543 | Sequential scans for hotel and review filtering; substring search is expensive. | GIN trigram index and hotel city/rating index. | 2.149 | 61.23% | SQL unchanged |
| R19 | 2,199.812 | Correlated passenger-count subquery executes repeatedly for each flight. | Replaced correlated subquery with joins and grouped aggregation. | 17.616 | 99.20% | Yes – EXCEPT ALL passed |
| R20 | 13.500 | Date cast on booked_at prevents direct timestamp index filtering. | Half-open June timestamp range and covering booked_at index. | 2.776 | 79.44% | Yes – EXCEPT ALL passed |
| R21 | 37.802 | Sequential scans on passengers, flight_bookings and flights. | Partial senior-passenger index and departure index. | 30.444 | 19.46% | SQL unchanged |
| R22 | 64.651 | Large OFFSET pagination requires skipping many rows. | Covering descending booked_at index; OFFSET retained for identical output. | 12.601 | 80.51% | SQL unchanged |
| R23 | 10.569 | Sequential scan on customers for case-insensitive email lookup. | Expression index on lower(email). | 0.069 | 99.35% | SQL unchanged |
| R24 | 2.957 | Review aggregation remains necessary; hotel city index does not eliminate all work. | Hotel city/rating index. | 4.447 | -50.39% | SQL unchanged |
| R25 | 45.313 | Multiple joins and timestamp arithmetic; substantial rows still need processing. | Covering booked_at index narrows booking-date filtering. | 32.160 | 29.03% | SQL unchanged |
| W01 | 1.443 | INSERT operation; indexes require maintenance. | No query rewrite. | 1.033 | 28.41% | SQL unchanged |
| W02 | 21.398 | Pending-payment lookup originally required inefficient access. | Partial index for PENDING_PAYMENT bookings. | 0.863 | 95.97% | SQL unchanged |
| W03 | 0.675 | Existing unique booking-reference lookup is already efficient. | Retained existing unique index. | 0.924 | -36.89% | SQL unchanged |
| W04 | 4.174 | Flight status/departure update filtering. | Composite status/departure index. | 1.616 | 61.28% | SQL unchanged |
| W05 | 7.736 | Unassigned hotel-room update filtering. | Partial index for rows where room_number IS NULL. | 3.194 | 58.71% | SQL unchanged |
| **Total** | **2,824.602** | | | **281.797** | **90.02%** | |

**Note:** SQL unchanged means the original query text was retained and the performance change came from indexes or the execution plan. R13 is a correctness correction, so its result is intentionally different from the incorrect original output.

## 3. Main Optimization Techniques

### 3.1 Sargable timestamp ranges

R01, R02, R12 and R20 were rewritten to avoid applying functions or casts to timestamp columns in their filtering conditions.

For example, instead of:

```sql
DATE(departure_at) = '2026-07-05'
```

the optimized query uses:

```sql
departure_at >= '2026-07-05 00:00:00+05:30'
AND departure_at < '2026-07-06 00:00:00+05:30'
```

This half-open range allows PostgreSQL to use B-tree indexes on timestamp columns more effectively and avoids applying a function to every candidate row.

### 3.2 Composite and covering indexes

Composite indexes were created for queries that filter on multiple columns.

For example, the route/departure index supports route equality conditions followed by departure timestamp filtering.

Covering indexes use `INCLUDE` columns to make required query output available from the index when PostgreSQL can perform an index-only scan.

### 3.3 Partial indexes

Partial indexes store only rows matching a condition.

Examples include:

- Pending-payment bookings for W02.
- Senior passengers for R21.
- Hotel bookings without assigned room numbers for W05.

This reduces the index size compared with indexing every row when the query only needs a subset.

### 3.4 Expression and GIN indexes

The expression index on `lower(email)` supports the case-insensitive lookup in R23.

The GIN trigram index supports substring searches such as:

```sql
review_text ILIKE '%breakfast%'
```

### 3.5 Join and aggregation rewrite – R19

The original R19 query used a correlated subquery to count passengers for each flight.

The optimized query uses joins and grouped aggregation:

```sql
SELECT f.flight_id, f.flight_no, f.departure_at,
       count(p.booking_id) AS passengers
FROM flights f
LEFT JOIN flight_bookings fb ON fb.flight_id = f.flight_id
LEFT JOIN passengers p       ON p.booking_id = fb.booking_id
WHERE f.departure_at >= '2026-06-01'
  AND f.departure_at < '2026-07-01'
GROUP BY f.flight_id, f.flight_no, f.departure_at
ORDER BY passengers DESC, f.departure_at;
```

This avoids repeatedly executing the correlated passenger-count query.

Execution time decreased from **2,199.812 ms to 17.616 ms**, a **99.20% improvement**.

### 3.6 Materialized view – R16

The original R16 query performs aggregation across bookings, customers, flight bookings, flights and hotel bookings.

The optimized query reads the precomputed summary:

```sql
SELECT booking_type, loyalty_tier, avg_lead_days
FROM mv_lead_days_by_tier
ORDER BY 1, 2;
```

The materialized view stores the grouped result and avoids repeating the expensive aggregation for every report request.

**Refresh policy:** Refresh the materialized view after booking data is loaded or changed, according to the application's reporting freshness requirement. A nightly refresh is suitable when daily reporting freshness is acceptable.

## 4. Wrong Result Due to SQL NULL Behaviour – R13

The original R13 query was:

```sql
SELECT c.coupon_code, c.applies_to, c.discount_pct
FROM coupons c
WHERE c.coupon_code NOT IN (
    SELECT b.coupon_code
    FROM bookings b
);
```

The problem is that the `bookings.coupon_code` column contains NULL values.

When a `NOT IN` subquery contains NULL, the comparison can evaluate to UNKNOWN. Consequently, coupons that have never been used can be excluded incorrectly.

The corrected query is:

```sql
SELECT c.coupon_code, c.applies_to, c.discount_pct
FROM coupons c
WHERE NOT EXISTS (
    SELECT 1
    FROM bookings b
    WHERE b.coupon_code = c.coupon_code
);
```

`NOT EXISTS` checks whether a matching booking exists for each coupon. An unrelated NULL value does not invalidate the comparison.

### Verification

The database verification returned:

| Check | Result |
|---|---:|
| NULL coupon codes in bookings | 127,144 |
| Rows returned by original NOT IN query | 0 |
| Rows returned by corrected NOT EXISTS query | 10 |

This confirms the original query's NULL-related problem and the corrected query's expected behaviour.

The corrected R13 query is intentionally not required to return the same rows as the incorrect original query.

Its optimized average execution time is **16.059 ms**, compared with the baseline **24.144 ms**.

## 5. Five Biggest Improvements and EXPLAIN Plans

The five largest percentage improvements are:

| Query | Baseline (ms) | Optimized (ms) | Improvement |
|---|---:|---:|---:|
| R16 | 118.169 | 0.046 | 99.96% |
| R23 | 10.569 | 0.069 | 99.35% |
| R19 | 2,199.812 | 17.616 | 99.20% |
| R05 | 14.428 | 0.194 | 98.66% |
| R11 | 11.955 | 0.163 | 98.64% |

### 5.1 Plan comparison

| Query | Baseline plan summary | Optimized plan summary |
|---|---|---|
| R16 | Sequential scans and aggregation across multiple base tables. | Reads the precomputed materialized-view summary. |
| R23 | Sequential scan on customers. | Index Scan using idx_customers_lower_email. |
| R19 | Correlated passenger-count subquery with repeated execution. | Join and aggregation; departure and passenger lookup indexes support access. |
| R05 | Sequential scan on bookings with primary-key joins. | Index Only Scan using idx_bookings_customer_status and primary-key joins. |
| R11 | Sequential scan on bookings. | Index Only Scan using idx_bookings_status_booked_at. |

### 5.2 Raw before-and-after EXPLAIN plans

The full raw plan outputs are retained in the repository. Each file contains the benchmark's `EXPLAIN (ANALYZE, BUFFERS)` output.

**R16**
- Baseline: `benchmarks/results/baseline/R16.txt`
- Optimized: `benchmarks/results/optimized/R16.txt`

**R23**
- Baseline: `benchmarks/results/baseline/R23.txt`
- Optimized: `benchmarks/results/optimized/R23.txt`

**R19**
- Baseline: `benchmarks/results/baseline/R19.txt`
- Optimized: `benchmarks/results/optimized/R19.txt`

**R05**
- Baseline: `benchmarks/results/baseline/R05.txt`
- Optimized: `benchmarks/results/optimized/R05.txt`

**R11**
- Baseline: `benchmarks/results/baseline/R11.txt`
- Optimized: `benchmarks/results/optimized/R11.txt`

These raw files should be committed along with this report so the complete plans, actual rows, buffers and execution-time details can be inspected.

## 6. Write Query Overhead

Indexes improve read performance but require maintenance during INSERT, UPDATE and DELETE operations.

The following table compares the five write-query averages.

| Write query | Baseline (ms) | Optimized (ms) | Time change (ms) | Result |
|---|---:|---:|---:|---|
| W01 | 1.443 | 1.033 | -0.410 | Faster |
| W02 | 21.398 | 0.863 | -20.535 | Faster |
| W03 | 0.675 | 0.924 | +0.249 | Slower |
| W04 | 4.174 | 1.616 | -2.558 | Faster |
| W05 | 7.736 | 3.194 | -4.542 | Faster |

W03 became slower by **0.249 ms**, approximately **36.89%**.

The other four write queries became faster in the recorded benchmark.

W03 already uses the unique booking-reference index. Its small increase may be due to index maintenance or run-to-run variation. The scan summary alone does not prove the exact cause.

The absolute increase is small, so it is acceptable for this workload, but it is still reported as a write-performance regression.

## 7. Index Storage and Justification

Index storage was measured using PostgreSQL's `pg_relation_size`.

The following recorded measurements compare each index with its associated table or relation.

| Table / relation | Index | Index size | Table / relation size | Purpose |
|---|---|---:|---:|---|
| bookings | idx_bookings_status_booked_at | 11 MB | 15 MB | R11 and R17: status filtering followed by booked_at filtering/ordering; included columns support covering access. |
| bookings | idx_bookings_booked_at_cover | 9,552 kB | 15 MB | R09, R12, R20, R22 and R25: booking-date filtering/ordering with included columns. |
| bookings | idx_bookings_customer_status | 9,352 kB | 15 MB | R05: customer and status equality filtering with included booking details. |
| customers | idx_customers_lower_email | 3,160 kB | 4,112 kB | R23: expression index matching lower(email). |
| flight_bookings | idx_flight_bookings_flight | 2,640 kB | 4,720 kB | R01, R07, R08, R19 and R21: flight join key with included booking/passenger columns. |
| hotel_bookings | idx_hotel_bookings_checkout_cover | 2,424 kB | 3,584 kB | R15: check-out overlap filtering with included columns. |
| hotel_bookings | idx_hotel_bookings_room_checkin | 2,400 kB | 3,584 kB | R04: room-type equality followed by check-in range filtering. |
| flights | idx_flights_route_departure | 1,176 kB | 1,288 kB | R01 and R02: route equality followed by departure timestamp filtering. |
| flights | idx_flights_status_departure | 824 kB | 1,288 kB | R08, R10 and W04: status filtering followed by departure timestamp filtering. |
| passengers | idx_passengers_senior | 776 kB | 9,368 kB | R21: partial index for passengers aged 60 or above. |
| flights | idx_flights_departure | 688 kB | 1,288 kB | R19 and R21: departure timestamp range filtering. |
| hotel_reviews | idx_hotel_reviews_hotel_created | 648 kB | 1,400 kB | R18 and R24: hotel join and review-date ordering. |
| hotel_reviews | idx_hotel_reviews_text_trgm | 504 kB | 1,400 kB | R18: GIN trigram index for substring searches. |
| hotels | idx_hotels_city_rating | 208 kB | 576 kB | R03, R18 and R24: city filtering and rating ordering. |
| hotel_bookings | idx_hotel_bookings_checkin_unassigned | 168 kB | 3,584 kB | W05: partial index for rows where room_number IS NULL. |
| bookings | idx_bookings_pending_id | 16 kB | 15 MB | W02: partial index for PENDING_PAYMENT bookings. |
| mv_lead_days_by_tier | uq_mv_lead_days_by_tier | 16 kB | 8 kB | R16: unique index on booking_type and loyalty_tier; supports concurrent refresh. |

The materialized-view index is compared with the materialized view relation itself.

Index sizes can vary after data changes, rebuilds and PostgreSQL maintenance. The recorded values should be reproducible using `pg_relation_size` on the same database.

## 8. Result-Equivalence Proof

The original and optimized versions of every rewritten performance query were compared using `EXCEPT ALL` in both directions.

This checks both row values and duplicate counts.

| Query | Original-only rows | Optimized-only rows | Result |
|---|---:|---:|---|
| R01 | 0 | 0 | Passed |
| R02 | 0 | 0 | Passed |
| R12 | 0 | 0 | Passed |
| R16 | 0 | 0 | Passed |
| R19 | 0 | 0 | Passed |
| R20 | 0 | 0 | Passed |

All six rewritten performance queries returned identical rows in both directions.

R13 is handled separately because the original query is incorrect due to NULL behaviour. The verification showed 127,144 NULL coupon codes, zero rows from the original query and ten rows from the corrected query.

**Important:** `EXCEPT ALL` verifies row values and duplicate counts. It does not verify output order. The queries with `ORDER BY` retain their ordering clauses.

## 9. Queries That Could Not Be Significantly Improved

Some queries still require substantial table access, joins or aggregation. Adding an index does not guarantee that PostgreSQL will use it or that it will reduce execution time.

| Query | Observation | Reason |
|---|---|---|
| R09 | Improved by 32.30%, but still takes 18.041 ms. | Route aggregation requires joining bookings, flight_bookings and flights and grouping many matching rows. |
| R14 | Improved by only 1.71%. | Cancellation-rate calculation requires aggregation across multiple related tables. |
| R15 | Improved by only 3.77%. | Room-night calculation uses date overlap arithmetic and aggregation by city. |
| R17 | Improved by 16.96%. | Customer-level grouping and HAVING conditions still require processing completed bookings. |
| R21 | Improved by 19.46%. | The query still joins passengers, flight_bookings and flights before grouping by route. |
| R24 | Became 50.39% slower. | Review aggregation and the requirement to count and average reviews remain expensive; the selected index did not improve the complete plan. |
| R25 | Improved by 29.03%. | Timestamp arithmetic and multiple joins still require processing matching bookings and flights. |

These queries are candidates for further investigation on the larger dataset. Their execution plans should guide any additional optimization rather than adding indexes without evidence.

## 10. Conclusion

Phase 4 achieved a **90.02% reduction** in the sum of average execution times across the 30-query workload.

The largest improvements came from:

- Using a materialized view for R16.
- Replacing the correlated subquery in R19 with joins and aggregation.
- Adding an expression index for R23.
- Adding covering indexes for R05 and R11.
- Rewriting timestamp filters into half-open ranges.

All six rewritten performance queries passed the bidirectional `EXCEPT ALL` comparison.

The incorrect NULL behaviour in R13 was identified and corrected using `NOT EXISTS`. The write-query comparison also identified W03 as a small performance regression.

The index storage and write overhead have been documented. Some analytical queries still require broad joins and aggregation, and R24 became slower despite indexing.

The next phase should evaluate these optimizations against the larger dataset, inspect any new bottlenecks and determine whether partitioning, query redesign or additional summary structures are necessary.

---

**Phase 4 deliverables:**
- `sql/05_indexes.sql`
- `sql/06_optimized_queries.sql`
- `docs/04_optimization_report.md`
- `benchmarks/results/baseline/`
- `benchmarks/results/optimized/`


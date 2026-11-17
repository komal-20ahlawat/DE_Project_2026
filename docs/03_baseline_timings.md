# Phase 3: Baseline Query Execution Timings

## 1. Benchmark method

- **Database:** MakeMyTrip Travel Booking Database
- **Schema:** `mmt`
- **Dataset:** Seed dataset (144,792 bookings)
- **Measurement:** `EXPLAIN (ANALYZE, BUFFERS)`
- **Runs:** 3 per query
- **Timing metric:** PostgreSQL `Execution Time` in milliseconds (not `Planning Time`)
- **Write-query method:** `W01`–`W05` measured inside `BEGIN; … ROLLBACK;` so the data is not changed

Each timing below is taken from the `Execution Time` line in the corresponding raw plan. The average is the arithmetic mean of the three runs, rounded to three decimal places.

## 2. Baseline execution timing table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Flight search: Delhi → Mumbai on 5 July 2026 with seats left | READ | 16.381 | 13.562 | 11.589 | 13.844 |
| R02: Fare calendar: cheapest Bengaluru → Delhi fare for each day of July 2026 | READ | 2.234 | 2.461 | 2.783 | 2.493 |
| R03: Hotel search: 4★+ hotels in Goa with a swimming pool, best rated first | READ | 1.645 | 1.062 | 0.904 | 1.204 |
| R04: Room availability: rooms left per room type of hotel 208 for 10–12 July 2026 | READ | 8.595 | 7.896 | 6.761 | 7.751 |
| R05: "My Trips": customer 1021's upcoming confirmed trips | READ | 17.425 | 13.421 | 12.439 | 14.428 |
| R06: Support: open a booking by its reference | READ | 0.093 | 0.121 | 0.160 | 0.125 |
| R07: Airline manifest: passengers on flight 13047 ordered by seat | READ | 10.706 | 8.611 | 6.721 | 8.679 |
| R08: Revenue management: July 2026 flights with fewer than 5 passengers booked | READ | 15.951 | 15.269 | 13.382 | 14.867 |
| R09: Trends: 10 most-booked routes in June 2026 | READ | 29.085 | 25.154 | 25.702 | 26.647 |
| R10: Flight status board: delayed flights | READ | 1.268 | 1.278 | 1.350 | 1.299 |
| R11: Payments: bookings waiting for payment for more than 30 minutes (checked at 23:59 on 30 Jun 2026) | READ | 12.636 | 11.336 | 11.893 | 11.955 |
| R12: Finance: revenue per booking type per month in 2026 (excluding cancellations) | READ | 50.498 | 46.897 | 47.387 | 48.261 |
| R13: Marketing: coupons that have never been used | READ | 24.160 | 24.266 | 24.006 | 24.144 |
| R14: Airline partnerships: cancellation rate of flight bookings per airline | READ | 55.131 | 53.271 | 55.350 | 54.584 |
| R15: Hotel partnerships: room-nights sold per city for stays in June 2026 | READ | 28.994 | 27.376 | 28.171 | 28.180 |
| R16: Insights: average days between booking and travel, per booking type and loyalty tier | READ | 124.223 | 116.249 | 114.036 | 118.169 |
| R17: Loyalty: customers with 3 or more completed trips that started in 2026 | READ | 31.065 | 32.199 | 33.932 | 32.399 |
| R18: Hotel page: Goa reviews that mention breakfast | READ | 5.463 | 5.617 | 5.549 | 5.543 |
| R19: Operations: passengers booked on every flight departing in June 2026 | READ | 2179.445 | 2169.335 | 2250.656 | 2199.812 |
| R20: Finance: bookings per day and running total for June 2026 | READ | 13.645 | 13.374 | 13.481 | 13.500 |
| R21: Concessions: senior-citizen passengers (60+) per route in 2026 | READ | 36.675 | 38.153 | 38.579 | 37.802 |
| R22: Support console: all bookings, newest first, page 4,001 (25 per page) | READ | 63.333 | 66.302 | 64.317 | 64.651 |
| R23: Sign-in: find the customer by email, ignoring case | READ | 10.813 | 10.435 | 10.458 | 10.569 |
| R24: Hotel ranking: Goa hotels with at least 5 reviews, by average review rating | READ | 2.901 | 3.101 | 2.868 | 2.957 |
| R25: Insights: last-minute flight bookings (made less than 24 hours before departure) in 2026 | READ | 55.883 | 37.929 | 42.127 | 45.313 |
| W01: Checkout: create a pending flight booking for customer 1021 | WRITE | 1.751 | 1.644 | 0.933 | 1.443 |
| W02: Payment gateway callback: confirm the oldest booking that is waiting for payment | WRITE | 23.071 | 20.280 | 20.844 | 21.398 |
| W03: Customer cancels booking MMA7772F with a 70% refund | WRITE | 0.501 | 0.754 | 0.771 | 0.675 |
| W04: Flight ops: every flight that was scheduled to depart before 1 July 2026 has now departed | WRITE | 4.320 | 3.903 | 4.299 | 4.174 |
| W05: Front desk: assign room numbers to every guest checking in on 1 July 2026 | WRITE | 8.385 | 7.247 | 7.575 | 7.736 |
| **Total (sum of all 30)** | | **2836.276** | **2778.503** | **2859.023** | **2824.601** |

**Average-time subtotals:**
- Read queries (`R01`–`R25`): **2789.175 ms**
- Write queries (`W01`–`W05`): **35.426 ms**
- All 30 queries: **2824.601 ms**

> The total row is the arithmetic sum of the separately measured query times. It is not the wall-clock duration of one combined workload execution.

## 3. Execution plan scan types and performance notes

Scan types below are taken from the supplied `EXPLAIN (ANALYZE, BUFFERS)` plans. The explanation gives one plan-based reason for the query's measured performance.

| SQL Query | Scan type(s) from plan | Why it is slow or fast |
|---|---|---|
| R01 | Seq Scan on flight_bookings; Seq Scan on flights; Index Scan using bookings_pkey on bookings | Sequential scans of flights and flight_bookings feed the join; bookings are then found through the primary-key index. The full flight_bookings scan is a major part of the work. |
| R02 | Seq Scan on flights | The flights table is scanned sequentially, then matching fares are aggregated and sorted by day. |
| R03 | Seq Scan on hotels | The hotels table is scanned and filtered by city, rating and pool criteria; only a small top-rated result set is returned. |
| R04 | Seq Scan on hotel_bookings; Index Scan using uq_room_hotel_pair on room_types; Index Scan using bookings_pkey on bookings | hotel_bookings is scanned for date overlap; room_types and bookings are fetched using indexes. |
| R05 | Seq Scan on bookings; Index Scan using flight_bookings_pkey on flight_bookings; Index Scan using flights_pkey on flights; Index Scan using hotel_bookings_pkey on hotel_bookings | The customer/status filter scans bookings; matching flight and hotel details are fetched through primary-key indexes. |
| R06 | Index Scan using bookings_booking_ref_key on bookings | The unique booking-reference index finds the booking directly, resulting in very few buffer reads and sub-millisecond execution. |
| R07 | Seq Scan on flight_bookings; Index Scan using bookings_pkey on bookings; Index Scan using pk_passengers on passengers | flight_bookings is scanned to locate the flight's bookings; indexed lookups fetch booking and passenger details, followed by sorting. |
| R08 | Seq Scan on flight_bookings; Seq Scan on flights | Both flights and flight_bookings are scanned, joined and grouped to count passengers; groups below five are filtered after aggregation. |
| R09 | Seq Scan on flight_bookings; Seq Scan on bookings; Seq Scan on flights | Large sequential scans of bookings and flight_bookings are joined with flights, then routes are grouped and top-N sorted. |
| R10 | Seq Scan on flights | All flights are checked for DELAYED status; only six rows qualify, so the final sort is small. |
| R11 | Seq Scan on bookings | A parallel sequential scan filters bookings by payment status and timestamp, then the qualifying rows are sorted. |
| R12 | Seq Scan on bookings | The bookings table is scanned, 2026 non-cancelled rows are sorted and grouped by month and booking type. |
| R13 | Seq Scan on coupons; Seq Scan on bookings | A hashed subplan is built by scanning bookings; coupons are also scanned to find codes absent from that set. |
| R14 | Seq Scan on bookings; Seq Scan on flight_bookings; Seq Scan on flights; Seq Scan on airlines | Bookings, flight_bookings, flights and airlines are joined; parallel aggregation computes airline cancellation rates before sorting. |
| R15 | Seq Scan on bookings; Seq Scan on hotel_bookings; Seq Scan on hotels | Bookings and hotel_bookings are scanned and joined to hotels; qualifying stay nights are aggregated by city. |
| R16 | Seq Scan on bookings; Seq Scan on customers; Seq Scan on flight_bookings; Seq Scan on flights; Seq Scan on hotel_bookings | Large booking and customer/detail relations are joined before grouping by booking type and loyalty tier; broad joins and aggregation dominate. |
| R17 | Seq Scan on bookings | Bookings are scanned and filtered, then hash-aggregated by customer. The plan reports temporary reads/writes from multi-batch aggregation. |
| R18 | Seq Scan on hotel_reviews; Seq Scan on hotels | hotel_reviews is scanned for the case-insensitive breakfast text match and hotels is scanned for Goa; matches are joined and top-N sorted. |
| R19 | Seq Scan on flights; Seq Scan on flight_bookings; Index Only Scan using pk_passengers on passengers | The correlated subquery rescans flight_bookings for each of 720 June flights (720 loops), causing extremely high repeated buffer activity and the longest runtime. |
| R20 | Seq Scan on bookings | Bookings are scanned in parallel, grouped by booking date and processed by a window aggregate to calculate the running total. |
| R21 | Seq Scan on passengers; Seq Scan on flight_bookings; Seq Scan on flights | passengers, flight_bookings and flights are sequentially scanned and hash-joined; age >= 60 is filtered before routes are grouped and sorted. |
| R22 | Seq Scan on bookings | All 144,792 bookings are sequentially scanned and sorted by booked_at. The sort spills to disk (external merge, 8,224 kB), making deep pagination expensive. |
| R23 | Seq Scan on customers | A sequential scan checks lower(email) for the requested address and removes 39,999 non-matching customers; the lower() predicate is not served by a plain email index in this plan. |
| R24 | Seq Scan on hotel_reviews; Seq Scan on hotels | hotel_reviews and hotels are sequentially scanned and hash-joined; results are grouped by hotel, filtered to at least five reviews, then top-N sorted by average rating. |
| R25 | Seq Scan on flight_bookings; Seq Scan on bookings; Seq Scan on flights | Bookings, flight_bookings and flights are sequentially scanned and hash-joined. The less-than-24-hour condition is applied as a join filter, removing 25,282 joined rows before sorting. |
| W01 | No scan node (single-row INSERT) | A single-row INSERT is executed. Foreign-key constraint triggers for customer and coupon checks run; the plan shows buffer activity but no table scan node. |
| W02 | Index Scan using bookings_pkey on bookings | The oldest pending-payment booking is found by walking the bookings primary-key index and filtering status, then the target row is updated through its primary-key index. The scan removes nearly the entire table before finding the row. |
| W03 | Index Scan using bookings_booking_ref_key on bookings | The booking is located directly through the unique booking-reference index and updated; this is the fastest write in the supplied set. |
| W04 | Seq Scan on flights | The flights table is sequentially scanned to find scheduled/delayed flights before the cutoff, then the qualifying rows are updated. |
| W05 | Seq Scan on hotel_bookings; Index Scan using bookings_pkey on bookings | hotel_bookings is sequentially scanned for unassigned rooms checking in on the target date; matching bookings are checked through repeated primary-key index lookups before update. |

## 4. Baseline observations

- **Slowest query:** R19, average **2,199.812 ms**. Its correlated subquery rescans `flight_bookings` for each of 720 June flights.
- **Fastest query:** R06, average **0.125 ms**. It uses the unique `bookings_booking_ref_key` index to locate a booking directly.
- **Slowest write query:** W02, average **21.398 ms**. The primary-key index scan filters out nearly the entire table while searching for the oldest pending-payment booking.
- **Deep pagination:** R22 performs a sequential scan and an external-merge sort that spills to disk (8,224 kB).
- **Common baseline pattern:** Sequential scans are common. They are not automatically inefficient; consider table size, selectivity, rows returned, loops, buffers and the rest of the plan.

## 5. Raw benchmark files

The raw evidence for the 30-query baseline consists of `R01.txt`–`R25.txt`, `W01.txt`–`W05.txt`, and `summary.csv`, stored under `benchmarks/results/baseline/` as specified by the project README.
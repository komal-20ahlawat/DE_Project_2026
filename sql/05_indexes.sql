-- Purpose:
--   Indexes and materialized view to support the optimized workload.
--
-- Important:
--   1. Run this file after 01_schema.sql and after loading seed data.
--   2. Run without wrapping the entire file in BEGIN/COMMIT because
--      VACUUM cannot run inside a transaction block.
--   3. Run this file once on a fresh database. If rerunning it,
--      drop the existing indexes and materialized view first.
--   4. Index Only Scans are possible when the required columns are
--      covered, but PostgreSQL chooses the execution plan.
--
-- Existing indexes from primary keys / unique constraints are not
-- recreated here.
-- =====================================================================

SET search_path TO mmt, public;

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA mmt;

SET search_path TO mmt, public;


-- =====================================================================
-- 1. FLIGHTS
-- =====================================================================

-- R01, R02:
-- Equality filters on origin and destination come first, followed by
-- the departure_at range condition.
-- INCLUDE columns cover the flight columns used by R01 and base_fare
-- used by R02. R01 also joins flight_bookings using flight_id.

CREATE INDEX idx_flights_route_departure
ON flights (origin, destination, departure_at)
INCLUDE (flight_id, flight_no, arrival_at, base_fare, total_seats, status);


-- R08, R10, W04:
-- status is used as an equality condition in R08 and R10.
-- departure_at supports date filtering and ordering.
-- W04 checks two status values, so a normal composite index is used
-- instead of a partial index for only one status.

CREATE INDEX idx_flights_status_departure
ON flights (status, departure_at)
INCLUDE (flight_id, flight_no, origin, destination);


-- R19, R21:
-- Both queries filter flights using a departure_at range.
-- departure_at is the leading key because there is no equality
-- condition on status, origin, or destination.
-- Included columns support joins and report output.

CREATE INDEX idx_flights_departure
ON flights (departure_at)
INCLUDE (flight_id, flight_no, origin, destination);


-- =====================================================================
-- 2. FLIGHT_BOOKINGS
-- =====================================================================

-- R01, R07, R08, R19, R21:
-- These queries join flights to flight_bookings using flight_id.
-- The primary key is on booking_id, so a separate index on flight_id
-- is useful.
-- booking_id supports subsequent joins; passengers supports passenger
-- aggregation in R01 and R08.

CREATE INDEX idx_flight_bookings_flight
ON flight_bookings (flight_id)
INCLUDE (booking_id, passengers);


-- =====================================================================
-- 3. PASSENGERS
-- =====================================================================

-- R21:
-- Only passengers aged 60 or above are required.
-- A partial index stores only qualifying passengers.
-- booking_id supports the join with flight_bookings.

CREATE INDEX idx_passengers_senior
ON passengers (booking_id)
WHERE age >= 60;


-- =====================================================================
-- 4. BOOKINGS
-- =====================================================================

-- R05:
-- Filters using customer_id and status.
-- Equality columns are used as the index keys.
-- Included columns support the selected booking details and joins.

CREATE INDEX idx_bookings_customer_status
ON bookings (customer_id, status)
INCLUDE (booking_id, booking_ref, booking_type, total_amount);


-- R09, R12, R20, R22, R25:
-- booked_at is used for date-range filtering and ordering.
-- DESC supports R22's ORDER BY booked_at DESC.
-- Included columns cover the booking information required by these
-- queries and support joins through booking_id.

CREATE INDEX idx_bookings_booked_at_cover
ON bookings (booked_at DESC)
INCLUDE (booking_id, booking_ref, booking_type, status, total_amount);


-- R11, R17:
-- Both queries filter by status and then use a booked_at condition.
-- Therefore, status is the equality key and booked_at is the range key.
-- Included columns support selected values and aggregation.

CREATE INDEX idx_bookings_status_booked_at
ON bookings (status, booked_at)
INCLUDE (booking_id, booking_ref, customer_id, total_amount);


-- W02:
-- Finds the minimum booking_id among pending-payment bookings.
-- A partial index stores only PENDING_PAYMENT rows, reducing index size.

CREATE INDEX idx_bookings_pending_id
ON bookings (booking_id)
WHERE status = 'PENDING_PAYMENT';


-- R13:
-- R13 retains the original NOT IN query to preserve its exact NULL
-- semantics. No separate coupon_code index is added for this query.


-- =====================================================================
-- 5. HOTEL_BOOKINGS
-- =====================================================================

-- R04:
-- Joins using room_type_id and checks overlapping stay dates.
-- room_type_id is the equality key, followed by the check_in range.
-- check_out and rooms are included for the overlap condition and
-- room aggregation. booking_id supports the join with bookings.

CREATE INDEX idx_hotel_bookings_room_checkin
ON hotel_bookings (room_type_id, check_in)
INCLUDE (booking_id, check_out, rooms);


-- R15:
-- Finds hotel stays overlapping June 2026.
-- check_out is indexed for its range condition.
-- check_in is checked as the other side of the overlap condition.
-- Included columns support joins and room-night calculations.

CREATE INDEX idx_hotel_bookings_checkout_cover
ON hotel_bookings (check_out)
INCLUDE (booking_id, check_in, hotel_id, rooms);


-- W05:
-- Finds bookings checking in on a particular date that have no room
-- number assigned yet.
-- The partial index stores only rows where room_number IS NULL.
-- booking_id supports the join with bookings.

CREATE INDEX idx_hotel_bookings_checkin_unassigned
ON hotel_bookings (check_in)
INCLUDE (booking_id)
WHERE room_number IS NULL;


-- =====================================================================
-- 6. HOTELS
-- =====================================================================

-- R03, R18, R24:
-- All three queries filter hotels by city_name.
-- R03 also sorts by user_rating DESC NULLS LAST, so the index uses
-- the same ordering to help with its LIMIT.
-- hotel_id supports joins with hotel_reviews.
-- star_rating and hotel_name support filtering and selected columns.

CREATE INDEX idx_hotels_city_rating
ON hotels (city_name, user_rating DESC NULLS LAST)
INCLUDE (hotel_id, star_rating, hotel_name);


-- =====================================================================
-- 7. HOTEL_REVIEWS
-- =====================================================================

-- R18, R24:
-- hotel_id supports joins between hotels and hotel_reviews.
-- created_at DESC supports ordering within hotel-based access.
-- rating is included for the average-rating calculation in R24.
-- R18's global ORDER BY across multiple hotels may still require a sort.

CREATE INDEX idx_hotel_reviews_hotel_created
ON hotel_reviews (hotel_id, created_at DESC)
INCLUDE (rating);


-- R18:
-- ILIKE '%breakfast%' has a leading wildcard, so a normal B-tree
-- index is not suitable.
-- GIN with pg_trgm supports substring matching.

CREATE INDEX idx_hotel_reviews_text_trgm
ON hotel_reviews
USING GIN (review_text gin_trgm_ops);


-- =====================================================================
-- 8. CUSTOMERS
-- =====================================================================

-- R23:
-- The query uses lower(email), while the existing UNIQUE constraint
-- indexes email without applying lower().
-- This expression index matches the exact WHERE expression.
-- Included columns support the customer details returned by the query.

CREATE INDEX idx_customers_lower_email
ON customers (lower(email))
INCLUDE (customer_id, full_name, loyalty_tier);


-- =====================================================================
-- 9. MATERIALIZED VIEW
-- =====================================================================

-- R16:
-- The original report calculates average lead days grouped by
-- booking_type and loyalty_tier.
-- This materialized view stores that aggregation so R16 does not
-- need to recalculate it every time.
--
-- Refresh policy:
-- Refresh nightly after the day's booking data is loaded:
--
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mmt.mv_lead_days_by_tier;
--
-- CONCURRENTLY requires a unique index on the materialized view.
-- The report reflects data as of its latest refresh.

CREATE MATERIALIZED VIEW mv_lead_days_by_tier AS
SELECT
    b.booking_type,
    c.loyalty_tier,
    round(
        avg(
            coalesce(f.departure_at::date, hb.check_in)
            - b.booked_at::date
        ),
        1
    ) AS avg_lead_days
FROM bookings b
JOIN customers c
    ON c.customer_id = b.customer_id
LEFT JOIN flight_bookings fb
    ON fb.booking_id = b.booking_id
LEFT JOIN flights f
    ON f.flight_id = fb.flight_id
LEFT JOIN hotel_bookings hb
    ON hb.booking_id = b.booking_id
GROUP BY
    b.booking_type,
    c.loyalty_tier;


-- Unique index required for REFRESH MATERIALIZED VIEW CONCURRENTLY.

CREATE UNIQUE INDEX uq_mv_lead_days_by_tier
ON mv_lead_days_by_tier (booking_type, loyalty_tier);


-- =====================================================================
-- 10. UPDATE STATISTICS AND VISIBILITY MAPS
-- =====================================================================

-- ANALYZE updates planner statistics.
-- VACUUM helps maintain visibility maps, which can make Index Only
-- Scans possible when the required pages are all-visible.
--
-- Run outside an explicit transaction block.

VACUUM (ANALYZE);
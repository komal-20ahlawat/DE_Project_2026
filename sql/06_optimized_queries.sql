-- =====================================================================
-- MakeMyTrip DBMS Project: optimized versions of the 30 queries (Phase 4)
--   Copy of queries/workload_30.sql. ONLY the queries marked
--   "-- OPTIMIZED:" below were changed; all others are identical to the
--   original (they are sped up by the indexes in sql/05_indexes.sql).
-- =====================================================================
SET search_path TO mmt;
BEGIN;

-- @R01
-- Flight search: Delhi → Mumbai on 5 July 2026 with seats left
-- OPTIMIZED: DATE(departure_at) = '...' replaced by a sargable range so
-- idx_flights_route_departure is used; flight_bookings joined via
-- idx_flight_bookings_flight.
SELECT f.flight_id, f.flight_no, f.departure_at, f.arrival_at, f.base_fare,
       f.total_seats - coalesce(sum(fb.passengers) FILTER (WHERE b.status <> 'CANCELLED'), 0) AS seats_left
FROM flights f
LEFT JOIN flight_bookings fb ON fb.flight_id = f.flight_id
LEFT JOIN bookings b         ON b.booking_id = fb.booking_id
WHERE f.origin = 'DEL' AND f.destination = 'BOM'
  AND f.departure_at >= '2026-07-05 00:00:00+05:30'
  AND f.departure_at <  '2026-07-06 00:00:00+05:30'
  AND f.status <> 'CANCELLED'
GROUP BY f.flight_id, f.flight_no, f.departure_at, f.arrival_at, f.base_fare, f.total_seats
ORDER BY f.departure_at;

-- @R02
-- Fare calendar: cheapest Bengaluru → Delhi fare for each day of July 2026
-- OPTIMIZED: departure_at::date BETWEEN ... replaced by a sargable range
-- (Index Only Scan on idx_flights_route_departure).
SELECT departure_at::date AS day, min(base_fare) AS cheapest_fare
FROM flights
WHERE origin = 'BLR' AND destination = 'DEL'
  AND departure_at >= '2026-07-01 00:00:00+05:30'
  AND departure_at <  '2026-08-01 00:00:00+05:30'
GROUP BY 1
ORDER BY 1;

-- @R03
-- Hotel search: 4★+ hotels in Goa with a swimming pool, best rated first
SELECT hotel_id, hotel_name, star_rating, user_rating
FROM hotels
WHERE city_name = 'Goa'
  AND star_rating >= 4
  AND amenities ->> 'pool' = 'true'
ORDER BY user_rating DESC NULLS LAST
LIMIT 20;

-- @R04
-- Room availability: rooms left per room type of hotel 208 for 10–12 July 2026
SELECT rt.room_type_id, rt.room_name, rt.price_per_night,
       rt.total_rooms - coalesce(sum(hb.rooms) FILTER (WHERE b.status <> 'CANCELLED'), 0) AS rooms_left
FROM room_types rt
LEFT JOIN hotel_bookings hb ON hb.room_type_id = rt.room_type_id
                           AND hb.check_in < '2026-07-12' AND hb.check_out > '2026-07-10'
LEFT JOIN bookings b        ON b.booking_id = hb.booking_id
WHERE rt.hotel_id = 208
GROUP BY rt.room_type_id, rt.room_name, rt.price_per_night, rt.total_rooms
ORDER BY rt.price_per_night;

-- @R05
-- "My Trips": customer 1021's upcoming confirmed trips
SELECT b.booking_ref, b.booking_type, b.total_amount,
       coalesce(f.departure_at::date, hb.check_in) AS travel_date
FROM bookings b
LEFT JOIN flight_bookings fb ON fb.booking_id = b.booking_id
LEFT JOIN flights f          ON f.flight_id = fb.flight_id
LEFT JOIN hotel_bookings hb  ON hb.booking_id = b.booking_id
WHERE b.customer_id = 1021 AND b.status = 'CONFIRMED'
ORDER BY travel_date;

-- @R06
-- Support: open a booking by its reference
SELECT booking_id, customer_id, booking_type, status, total_amount, booked_at
FROM bookings
WHERE booking_ref = 'MMA7772F';

-- @R07
-- Airline manifest: passengers on flight 13047 ordered by seat
SELECT p.full_name, p.age, p.gender, p.seat_no, b.booking_ref
FROM flight_bookings fb
JOIN bookings b   ON b.booking_id = fb.booking_id AND b.status <> 'CANCELLED'
JOIN passengers p ON p.booking_id = fb.booking_id
WHERE fb.flight_id = 13047
ORDER BY p.seat_no NULLS LAST, p.full_name;

-- @R08
-- Revenue management: July 2026 flights with fewer than 5 passengers booked
SELECT f.flight_id, f.flight_no, f.departure_at, coalesce(sum(fb.passengers), 0) AS passengers
FROM flights f
LEFT JOIN flight_bookings fb ON fb.flight_id = f.flight_id
WHERE f.departure_at >= '2026-07-01' AND f.status = 'SCHEDULED'
GROUP BY f.flight_id, f.flight_no, f.departure_at
HAVING coalesce(sum(fb.passengers), 0) < 5
ORDER BY f.departure_at;

-- @R09
-- Trends: 10 most-booked routes in June 2026
SELECT f.origin, f.destination, count(*) AS bookings, sum(fb.passengers) AS passengers
FROM bookings b
JOIN flight_bookings fb ON fb.booking_id = b.booking_id
JOIN flights f          ON f.flight_id = fb.flight_id
WHERE b.booked_at >= '2026-06-01' AND b.booked_at < '2026-07-01'
GROUP BY f.origin, f.destination
ORDER BY bookings DESC
LIMIT 10;

-- @R10
-- Flight status board: delayed flights
SELECT flight_id, flight_no, origin, destination, departure_at
FROM flights
WHERE status = 'DELAYED'
ORDER BY departure_at;

-- @R11
-- Payments: bookings waiting for payment for more than 30 minutes (checked at 23:59 on 30 Jun 2026)
SELECT booking_id, booking_ref, customer_id, total_amount, booked_at
FROM bookings
WHERE status = 'PENDING_PAYMENT'
  AND booked_at < TIMESTAMPTZ '2026-06-30 23:59:00+05:30' - interval '30 minutes'
ORDER BY booked_at;

-- @R12
-- Finance: revenue per booking type per month in 2026 (excluding cancellations)
-- OPTIMIZED: EXTRACT(YEAR FROM booked_at) = 2026 replaced by a sargable range
-- (idx_bookings_booked_at_cover, Index Only Scan).
SELECT date_trunc('month', booked_at) AS month, booking_type, count(*) AS bookings, sum(total_amount) AS revenue
FROM bookings
WHERE status <> 'CANCELLED'
  AND booked_at >= '2026-01-01 00:00:00+05:30'
  AND booked_at <  '2027-01-01 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R13
-- Marketing: coupons that have never been used
-- OPTIMIZED + RESULT FIXED: NOT IN (subquery containing NULLs) returns ZERO rows
-- because bookings.coupon_code is NULL for bookings without a coupon
-- (x NOT IN (..., NULL) is never TRUE). NOT EXISTS ignores NULLs and returns
-- the real unused coupons; uses idx_bookings_coupon.
SELECT c.coupon_code, c.applies_to, c.discount_pct
FROM coupons c
WHERE coupon_code NOT IN (
    SELECT coupon_code
    FROM bookings
)

-- @R14
-- Airline partnerships: cancellation rate of flight bookings per airline
SELECT a.airline_name, count(*) AS bookings,
       round(100.0 * count(*) FILTER (WHERE b.status = 'CANCELLED') / count(*), 2) AS cancel_pct
FROM bookings b
JOIN flight_bookings fb ON fb.booking_id = b.booking_id
JOIN flights f          ON f.flight_id = fb.flight_id
JOIN airlines a         ON a.airline_code = f.airline_code
GROUP BY a.airline_name
ORDER BY cancel_pct DESC;

-- @R15
-- Hotel partnerships: room-nights sold per city for stays in June 2026
SELECT h.city_name,
       sum(hb.rooms * (least(hb.check_out, DATE '2026-07-01') - greatest(hb.check_in, DATE '2026-06-01'))) AS room_nights
FROM hotel_bookings hb
JOIN hotels h   ON h.hotel_id = hb.hotel_id
JOIN bookings b ON b.booking_id = hb.booking_id AND b.status <> 'CANCELLED'
WHERE hb.check_in < '2026-07-01' AND hb.check_out > '2026-06-01'
GROUP BY h.city_name
ORDER BY room_nights DESC;
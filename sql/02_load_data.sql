-- Purpose:
-- Load all 12 CSV files into their respective tables.
-- Tables are loaded in parent-to-child dependency order.

-- Select the MMT schema
SET search_path TO mmt;


-- STEP 1: LOAD PARENT TABLES

-- 1. Airports
\copy airports FROM 'seed_data/airports.csv' WITH (FORMAT csv, HEADER true)

-- 2. Airlines
\copy airlines FROM 'seed_data/airlines.csv' WITH (FORMAT csv, HEADER true)

-- 3. Customers
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true)

-- 4. Coupons
\copy coupons FROM 'seed_data/coupons.csv' WITH (FORMAT csv, HEADER true)

-- 5. Hotels
\copy hotels FROM 'seed_data/hotels.csv' WITH (FORMAT csv, HEADER true)


-- STEP 2: LOAD DEPENDENT MASTER TABLES

-- 6. Room Types (references hotels)
\copy room_types FROM 'seed_data/room_types.csv' WITH (FORMAT csv, HEADER true)

-- 7. Flights (references airlines and airports)
\copy flights FROM 'seed_data/flights.csv' WITH (FORMAT csv, HEADER true)


-- STEP 3: LOAD BOOKINGS

-- 8. Bookings (references customers and coupons)
\copy bookings FROM 'seed_data/bookings.csv' WITH (FORMAT csv, HEADER true)


-- STEP 4: LOAD BOOKING DETAILS

-- 9. Flight Bookings (references bookings and flights)
\copy flight_bookings FROM 'seed_data/flight_bookings.csv' WITH (FORMAT csv, HEADER true)

-- 10. Hotel Bookings (references bookings, hotels and room_types)
\copy hotel_bookings FROM 'seed_data/hotel_bookings.csv' WITH (FORMAT csv, HEADER true)

-- 11. Passengers (references flight bookings)
\copy passengers FROM 'seed_data/passengers.csv' WITH (FORMAT csv, HEADER true)

-- 12. Hotel Reviews (references hotel bookings and hotels)
\copy hotel_reviews FROM 'seed_data/hotel_reviews.csv' WITH (FORMAT csv, HEADER true)


-- STEP 5: UPDATE TABLE STATISTICS

ANALYZE;


-- STEP 6: VERIFY ROW COUNTS

SELECT 'airports' AS table_name, COUNT(*) AS total_rows FROM airports
UNION ALL
SELECT 'airlines', COUNT(*) FROM airlines
UNION ALL
SELECT 'flights', COUNT(*) FROM flights
UNION ALL
SELECT 'hotels', COUNT(*) FROM hotels
UNION ALL
SELECT 'room_types', COUNT(*) FROM room_types
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'coupons', COUNT(*) FROM coupons
UNION ALL
SELECT 'bookings', COUNT(*) FROM bookings
UNION ALL
SELECT 'flight_bookings', COUNT(*) FROM flight_bookings
UNION ALL
SELECT 'passengers', COUNT(*) FROM passengers
UNION ALL
SELECT 'hotel_bookings', COUNT(*) FROM hotel_bookings
UNION ALL
SELECT 'hotel_reviews', COUNT(*) FROM hotel_reviews
ORDER BY table_name;


-- STEP 7: INTEGRITY CHECKS

-- Integrity Check 1:
-- Verify passenger count against the passengers column
-- in flight_bookings.

SELECT
    fb.booking_id,
    fb.passengers AS expected_passengers,
    COUNT(p.seq_no) AS actual_passengers
FROM flight_bookings fb
LEFT JOIN passengers p
    ON p.booking_id = fb.booking_id
GROUP BY fb.booking_id, fb.passengers
HAVING fb.passengers <> COUNT(p.seq_no);


-- Integrity Check 2:
-- Identify flight bookings made after their flight departed.

SELECT
    b.booking_id,
    b.booked_at,
    f.flight_id,
    f.departure_at
FROM bookings b
JOIN flight_bookings fb
    ON fb.booking_id = b.booking_id
JOIN flights f
    ON f.flight_id = fb.flight_id
WHERE b.booked_at > f.departure_at;


-- Integrity Check 3:
-- Verify that a booking cannot simultaneously be
-- a flight booking and a hotel booking.

SELECT
    b.booking_id,
    b.booking_type
FROM bookings b
JOIN flight_bookings fb
    ON fb.booking_id = b.booking_id
JOIN hotel_bookings hb
    ON hb.booking_id = b.booking_id;
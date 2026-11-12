# Schema Design — MakeMyTrip Travel Booking Database

**Database:** PostgreSQL 15+  
**Schema:** `mmt`  
**Checkpoint:** CP1 — Schema & Normalization

## 1. Design overview

The database stores MakeMyTrip's flight and hotel booking activity. The design separates reference data (airports, airlines, hotels, room types, coupons and customers), operational data (flights and bookings), booking-specific details (flight bookings, passengers and hotel bookings), and customer feedback (hotel reviews).

The schema contains all 12 source tables. Each table name and column name follows the supplied CSV file and header. Primary keys identify rows, foreign keys preserve relationships, and `NOT NULL`, `UNIQUE` and `CHECK` constraints enforce the rules that can be checked within an individual row or table.

All tables are created in the `mmt` schema. No manually created performance indexes are included in this checkpoint. PostgreSQL automatically creates indexes for primary-key and unique constraints; those are the only indexes expected from this DDL.

## 2. Tables, keys and relationships

| Table | Primary key | Foreign keys | Purpose and relationship |
|---|---|---|---|
| `airports` | `iata_code` | — | Airport reference data. One airport can be the origin of many flights and the destination of many flights. |
| `airlines` | `airline_code` | — | Airline reference data. One airline operates many flights. |
| `customers` | `customer_id` | — | Customer details. One customer can make many bookings. |
| `coupons` | `coupon_code` | — | Coupon definitions. One coupon can be referenced by many bookings; a booking may have no coupon. |
| `flights` | `flight_id` | `airline_code` → `airlines`; `origin` and `destination` → `airports` | A dated flight instance. Each flight belongs to one airline and has one origin and one destination. |
| `hotels` | `hotel_id` | — | Hotel details, ratings, amenities and check-in/check-out times. One hotel has many room types and hotel bookings. |
| `room_types` | `room_type_id` | `hotel_id` → `hotels` | Room categories belonging to a hotel. A hotel can have many room types. `(hotel_id, room_type_id)` is also unique so hotel bookings can enforce that the selected room type belongs to the selected hotel. |
| `bookings` | `booking_id` | `customer_id` → `customers`; `coupon_code` → `coupons` | Common booking information for both flight and hotel bookings. Each booking belongs to one customer and may use one coupon. |
| `flight_bookings` | `booking_id` | `booking_id` → `bookings`; `flight_id` → `flights` | Flight-specific details for a booking. The shared primary/foreign key makes the relationship with `bookings` one-to-zero-or-one. |
| `passengers` | (`booking_id`, `seq_no`) | `booking_id` → `flight_bookings` | One row per passenger in a flight booking. A flight booking can have multiple passengers. |
| `hotel_bookings` | `booking_id` | `booking_id` → `bookings`; `hotel_id` → `hotels`; (`hotel_id`, `room_type_id`) → `room_types` | Hotel stay details. Each hotel booking refers to one hotel and one room type belonging to that hotel. |
| `hotel_reviews` | `review_id` | `booking_id` → `hotel_bookings`; `hotel_id` → `hotels` | Review of a hotel stay. `booking_id` is also unique, so at most one review is stored for a hotel booking. |

### Relationship cardinalities

- `airlines` 1 : N `flights`.
- `airports` 1 : N `flights` through the separate `origin` and `destination` foreign keys.
- `customers` 1 : N `bookings`.
- `coupons` 1 : N `bookings`; each booking uses zero or one coupon.
- `hotels` 1 : N `room_types`.
- `bookings` 1 : 0..1 `flight_bookings`, and 1 : 0..1 `hotel_bookings`.
- `flights` 1 : N `flight_bookings`.
- `flight_bookings` 1 : N `passengers`.
- `hotels` 1 : N `hotel_bookings`.
- `room_types` 1 : N `hotel_bookings` (with the composite hotel/room-type reference).
- `hotel_bookings` 1 : 0..1 `hotel_reviews`; `hotels` 1 : N `hotel_reviews`.

A booking is intended to be either a flight booking or a hotel booking, not both. The supplied rows satisfy this rule. However, a normal `CHECK` constraint cannot inspect the other subtype table, so the current DDL does not independently enforce subtype exclusivity or subtype completeness. Those conditions are checked as cross-table integrity queries after loading. A trigger or a different modelling approach would be needed to enforce them automatically in the database.

## 3. Data dictionary and constraint rationale

The following tables describe the column types and the important constraints in `01_schema.sql`. `PK` means primary key, `FK` means foreign key, `UQ` means unique, `NN` means not null, and `CK` means check constraint.

### 3.1 `airports`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `iata_code` | `VARCHAR(3)` | PK, CK `^[A-Z]{3}$` | Three-letter uppercase airport identifier. |
| `airport_name` | `VARCHAR(150)` | NN | Airport name is required. |
| `city_name` | `VARCHAR(100)` | NN | City is required for airport location. |
| `country_code` | `CHAR(2)` | NN, CK `^[A-Z]{2}$` | Two-letter uppercase country code. |

### 3.2 `airlines`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `airline_code` | `VARCHAR(3)` | PK, CK `^[A-Z0-9]{2,3}$` | Short airline code; supports letters and digits. |
| `airline_name` | `VARCHAR(100)` | NN, UQ | Airline name is required and is kept unique in this dataset/schema. |

### 3.3 `customers`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `customer_id` | `INTEGER` | PK | Numeric customer identifier. |
| `full_name` | `VARCHAR(150)` | NN | Customer name is required. |
| `email` | `VARCHAR(255)` | NN, UQ, CK email-format pattern | Email is required and unique; the check rejects a basic malformed address. |
| `phone` | `VARCHAR(20)` | NN, UQ | Stored as text to preserve phone formatting and leading zeroes if present. |
| `loyalty_tier` | `VARCHAR(20)` | NN, CK in `BLUE`, `SILVER`, `GOLD`, `PLATINUM` | Restricts the tier to the values represented by the data. |
| `created_at` | `TIMESTAMPTZ` | NN | Customer creation time includes a UTC offset in the CSV. |

### 3.4 `coupons`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `coupon_code` | `VARCHAR(30)` | PK | Coupon identifier. |
| `applies_to` | `VARCHAR(10)` | NN, CK in `ALL`, `FLIGHT`, `HOTEL` | Defines which booking category can use the coupon. |
| `discount_pct` | `NUMERIC(5,2)` | NN, CK greater than 0 and at most 100 | Percentage requires a decimal-capable numeric type and a valid range. |
| `max_discount` | `NUMERIC(12,2)` | NN, CK greater than 0 | Monetary cap; decimal precision is required. |
| `valid_from` | `DATE` | NN | Start of the validity period. |
| `valid_to` | `DATE` | NN, CK `valid_to >= valid_from` | End date cannot precede the start date. |

### 3.5 `flights`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `flight_id` | `INTEGER` | PK | Unique dated-flight identifier. |
| `airline_code` | `VARCHAR(3)` | NN, FK → `airlines.airline_code`, delete RESTRICT | Every flight must reference an existing airline; an airline in use should not be deleted. |
| `flight_no` | `VARCHAR(10)` | NN, CK `^[A-Z0-9]{2,3}-[0-9]{3}$` | Flight number format observed in the seed data. |
| `origin` | `VARCHAR(3)` | NN, FK → `airports.iata_code`, delete RESTRICT | Origin must be a known airport. |
| `destination` | `VARCHAR(3)` | NN, FK → `airports.iata_code`, delete RESTRICT | Destination must be a known airport. |
| `departure_at` | `TIMESTAMPTZ` | NN | Scheduled departure includes a time-zone offset. |
| `arrival_at` | `TIMESTAMPTZ` | NN, CK later than departure | Arrival must be after departure. |
| `aircraft` | `VARCHAR(30)` | NN | Aircraft/model label. |
| `total_seats` | `INTEGER` | NN, CK greater than 0 | A flight must have a positive seat capacity. |
| `base_fare` | `NUMERIC(12,2)` | NN, CK greater than 0 | Fare is monetary and must be positive. |
| `status` | `VARCHAR(20)` | NN, CK in `SCHEDULED`, `DELAYED`, `DEPARTED`, `LANDED`, `CANCELLED` | Restricts flight state to the supported values. |

### 3.6 `hotels`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `hotel_id` | `INTEGER` | PK | Unique hotel identifier. |
| `hotel_name` | `VARCHAR(200)` | NN | Hotel name is required. |
| `city_name` | `VARCHAR(100)` | NN | City is used for hotel search and reporting. |
| `star_rating` | `SMALLINT` | NN, CK 1–5 | Small integer is suitable for a 1-to-5 rating. |
| `user_rating` | `NUMERIC(2,1)` | Nullable, CK NULL or 1–5 | Some hotels have no user rating; decimal rating is allowed. |
| `amenities` | `JSONB` | NN, CK JSON type is `object` | Amenities are represented as a JSON object of amenity names and boolean values (for example, `pool`, `wifi`, `breakfast`). JSONB preserves this semi-structured set. |
| `check_in_time` | `TIME` | NN | Local hotel check-in time, without a date. |
| `check_out_time` | `TIME` | NN | Local hotel check-out time, without a date. |

### 3.7 `room_types`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `room_type_id` | `INTEGER` | PK | Unique room-type identifier. |
| `hotel_id` | `INTEGER` | NN, FK → `hotels.hotel_id`, delete RESTRICT | Every room type belongs to an existing hotel. |
| `room_name` | `VARCHAR(100)` | NN | Room category name. |
| `max_guests` | `SMALLINT` | NN, CK greater than 0 | Maximum guest capacity must be positive. |
| `price_per_night` | `NUMERIC(12,2)` | NN, CK greater than 0 | Nightly price is monetary and positive. |
| `total_rooms` | `INTEGER` | NN, CK greater than 0 | Number of rooms available for this type must be positive. |

`UNIQUE (hotel_id, room_type_id)` supports the composite foreign key from `hotel_bookings`. Since `room_type_id` is already the primary key, this pair is logically unique as well; the additional unique constraint is present to make the composite referenced key explicit.

### 3.8 `bookings`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `booking_id` | `INTEGER` | PK | Unique booking identifier. |
| `booking_ref` | `VARCHAR(20)` | NN, UQ, CK `^[A-Z0-9]{8}$` | Customer-facing reference; unique and follows the seed format. |
| `customer_id` | `INTEGER` | NN, FK → `customers.customer_id`, delete RESTRICT | Every booking belongs to a customer; retain customer history. |
| `booking_type` | `VARCHAR(10)` | NN, CK `FLIGHT` or `HOTEL` | Identifies the product booked. |
| `booked_at` | `TIMESTAMPTZ` | NN | Booking creation timestamp includes an offset. |
| `total_amount` | `NUMERIC(12,2)` | NN, CK greater than 0 | Booking amount is monetary and positive. |
| `coupon_code` | `VARCHAR(30)` | Nullable, FK → `coupons.coupon_code`, delete RESTRICT | A booking may not use a coupon; referenced coupons should not be deleted. |
| `discount` | `NUMERIC(12,2)` | NN, default 0, CK between 0 and `total_amount` | Monetary discount; zero is the default when no discount is applied. |
| `payment_method` | `VARCHAR(20)` | NN, CK in `CARD`, `EMI`, `NETBANKING`, `UPI`, `WALLET` | Restricts payment method to the values in the dataset. |
| `status` | `VARCHAR(20)` | NN, CK in `PENDING_PAYMENT`, `CONFIRMED`, `COMPLETED`, `CANCELLED` | Restricts booking state. |
| `cancelled_at` | `TIMESTAMPTZ` | Nullable; paired with cancellation check | Only cancelled bookings have a cancellation timestamp in the seed data. |
| `refund_amount` | `NUMERIC(12,2)` | Nullable; paired with cancellation check and refund range check | Refund is absent for non-cancelled bookings; when present it must be between zero and the booking amount. |

The cancellation check requires both `cancelled_at` and `refund_amount` for a `CANCELLED` booking, and requires both to be NULL for a non-cancelled booking. The coupon/discount check prevents a non-zero discount when `coupon_code` is NULL.

### 3.9 `flight_bookings`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `booking_id` | `INTEGER` | PK, FK → `bookings.booking_id`, delete CASCADE | Shared key identifies the flight-specific extension of a booking. Deleting its parent booking removes its detail row. |
| `flight_id` | `INTEGER` | NN, FK → `flights.flight_id`, delete RESTRICT | Every flight booking refers to an existing flight; a booked flight should not be deleted. |
| `cabin` | `VARCHAR(20)` | NN, CK in `ECONOMY`, `PREMIUM`, `BUSINESS` | Restricts cabin category. |
| `passengers` | `SMALLINT` | NN, CK greater than 0 | Number of passengers must be positive. |
| `fare_paid` | `NUMERIC(12,2)` | NN, CK greater than 0 | Actual fare paid for the flight booking is monetary and positive. |

### 3.10 `passengers`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `booking_id` | `INTEGER` | Part of PK, FK → `flight_bookings.booking_id`, delete CASCADE | Passenger belongs to a flight booking; remove passenger rows if the parent flight booking is deleted. |
| `seq_no` | `SMALLINT` | Part of PK, CK greater than 0 | Passenger sequence is unique within a booking and starts above zero. |
| `full_name` | `VARCHAR(150)` | NN | Passenger name is required. |
| `age` | `SMALLINT` | NN, CK at least 0 | Age is a non-negative whole number. |
| `gender` | `CHAR(1)` | NN, CK in `M`, `F`, `X` | Stores one of the gender codes present in the data. |
| `seat_no` | `VARCHAR(5)` | Nullable, CK NULL or `^[0-9]{1,2}[A-F]$` | Seat may be unassigned before web check-in; assigned seats follow the observed format. |

The composite primary key `(booking_id, seq_no)` allows multiple passenger rows per booking while preventing duplicate sequence numbers within the same booking.

### 3.11 `hotel_bookings`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `booking_id` | `INTEGER` | PK, FK → `bookings.booking_id`, delete CASCADE | Shared key identifies the hotel-specific extension of a booking. |
| `hotel_id` | `INTEGER` | NN, FK → `hotels.hotel_id`, delete RESTRICT | The stay must refer to an existing hotel. |
| `room_type_id` | `INTEGER` | NN, composite FK with `hotel_id` → `room_types(hotel_id, room_type_id)`, delete RESTRICT | Ensures the selected room type belongs to the selected hotel. |
| `check_in` | `DATE` | NN | Stay start date. |
| `check_out` | `DATE` | NN, CK later than `check_in` | A stay must have at least one night. |
| `rooms` | `SMALLINT` | NN, CK greater than 0 | At least one room is booked. |
| `guests` | `SMALLINT` | NN, CK greater than 0 | At least one guest is included. |
| `room_number` | `VARCHAR(20)` | Nullable | Room assignment may be pending until check-in; text type accommodates room labels without treating them as numbers. |

### 3.12 `hotel_reviews`

| Column | PostgreSQL type | Constraint | Reason |
|---|---|---|---|
| `review_id` | `INTEGER` | PK | Unique review identifier. |
| `booking_id` | `INTEGER` | NN, UQ, FK → `hotel_bookings.booking_id`, delete CASCADE | Review must belong to a hotel booking; unique allows at most one review per booking. |
| `hotel_id` | `INTEGER` | NN, FK → `hotels.hotel_id`, delete RESTRICT | Identifies the reviewed hotel. |
| `rating` | `SMALLINT` | NN, CK 1–5 | Review rating must be within the five-point scale. |
| `title` | `VARCHAR(200)` | NN | Review title is required. |
| `review_text` | `TEXT` | Nullable | Some reviews have a title and rating but no written text. |
| `created_at` | `TIMESTAMPTZ` | NN | Review creation time includes an offset. |

## 4. NULL values in the seed data

The CSV inspection found NULL values in the following columns. These are treated as meaningful optional values rather than being replaced with arbitrary defaults.

| Table.column | NULL rows | Interpretation and schema decision |
|---|---:|---|
| `bookings.coupon_code` | 127,144 | Booking did not use a coupon; nullable foreign key. |
| `bookings.cancelled_at` | 133,298 | Booking is not cancelled; nullable and checked against `status`. |
| `bookings.refund_amount` | 133,298 | Booking is not cancelled; nullable and checked against `status`. |
| `hotels.user_rating` | 134 | No user rating is available for some hotels; nullable. |
| `passengers.seat_no` | 21,612 | Seat has not yet been assigned; nullable. |
| `hotel_bookings.room_number` | 6,815 | Room number has not yet been assigned; nullable. |
| `hotel_reviews.review_text` | 4,812 | Review has no written comment; nullable. |

All other columns in the 12 CSV files had no missing values in the inspected seed data. The DDL marks those columns `NOT NULL`.

## 5. Functional dependencies and normal forms

The following functional dependencies (FDs) are based on the declared keys and the meaning of the attributes. Each relation has a single-valued attribute set for each key. The schema is designed to satisfy 3NF; the listed key-based dependencies also satisfy BCNF for these relations.

| Table | Main functional dependency | Normal-form reasoning |
|---|---|---|
| `airports` | `iata_code → airport_name, city_name, country_code` | The airport code determines all non-key attributes; no partial dependency. BCNF. |
| `airlines` | `airline_code → airline_name`; `airline_name → airline_code` under the declared UQ rule | Both determinants are candidate keys in this schema. BCNF. |
| `customers` | `customer_id → full_name, email, phone, loyalty_tier, created_at`; `email → customer_id`; `phone → customer_id` under the UQ constraints | Each declared determinant is a candidate key. BCNF. |
| `coupons` | `coupon_code → applies_to, discount_pct, max_discount, valid_from, valid_to` | Coupon code determines the coupon attributes. BCNF. |
| `flights` | `flight_id → airline_code, flight_no, origin, destination, departure_at, arrival_at, aircraft, total_seats, base_fare, status` | Flight ID determines the dated flight instance. BCNF under the declared key. |
| `hotels` | `hotel_id → hotel_name, city_name, star_rating, user_rating, amenities, check_in_time, check_out_time` | Hotel ID determines hotel attributes. BCNF. |
| `room_types` | `room_type_id → hotel_id, room_name, max_guests, price_per_night, total_rooms` | Room type ID determines the room-type row. The declared `(hotel_id, room_type_id)` unique key is a superkey as well. BCNF. |
| `bookings` | `booking_id → booking_ref, customer_id, booking_type, booked_at, total_amount, coupon_code, discount, payment_method, status, cancelled_at, refund_amount`; `booking_ref → booking_id` | Booking ID and booking reference are candidate keys. BCNF. |
| `flight_bookings` | `booking_id → flight_id, cabin, passengers, fare_paid` | Booking ID is the primary key and determines flight-specific attributes. BCNF. |
| `passengers` | `(booking_id, seq_no) → full_name, age, gender, seat_no` | Non-key attributes depend on the whole composite key. BCNF. |
| `hotel_bookings` | `booking_id → hotel_id, room_type_id, check_in, check_out, rooms, guests, room_number` | Booking ID determines the stay details. BCNF under the declared key. |
| `hotel_reviews` | `review_id → booking_id, hotel_id, rating, title, review_text, created_at`; `booking_id → review_id, hotel_id, rating, title, review_text, created_at` because `booking_id` is unique | Both determinants are candidate keys under the declared constraints. BCNF. |

### Redundant or derived attributes

1. **`flight_bookings.passengers` and rows in `passengers`:** the passenger count can be derived by counting passenger rows for a booking. The count is retained because it is part of the supplied flight-booking export and is used directly by the given workload. The seed data check found that the stored count equals the number of passenger rows for every flight booking. If passenger rows are changed later, the count must be kept consistent (for example, by application logic or a trigger).
2. **`flight_bookings.fare_paid` versus `bookings.total_amount` and `bookings.discount`:** these values are related but are not interchangeable. `fare_paid` is the flight-specific fare amount, while `total_amount` and `discount` are stored at the overall booking level. The inspected data does not establish a universal equality: approximately 88.1% of flight rows have `fare_paid = total_amount - discount` to the cent, so the columns should not be collapsed based on that assumption. Retaining `fare_paid` preserves the source value and supports flight-specific analysis.
3. **`hotel_reviews.hotel_id` versus `hotel_bookings.hotel_id`:** the hotel can be obtained by joining the review's `booking_id` to `hotel_bookings`. The `hotel_id` in `hotel_reviews` is therefore redundant in principle, but it is retained because it exists in the source CSV and is used by the supplied review queries. The inspected data had no mismatch between these two hotel IDs. Since a normal foreign key cannot enforce equality across the two paths, a trigger or integrity query is needed to prevent future inconsistencies.
4. **`room_types.hotel_id` and `room_type_id`:** `room_type_id` is already the primary key, so `hotel_id` is functionally determined by it. The composite unique constraint is included to support the composite foreign key that verifies a hotel booking's room type belongs to the same hotel.
5. **`bookings.booking_type` and subtype tables:** the booking type is repeated conceptually by the existence of a row in either `flight_bookings` or `hotel_bookings`. It is retained because it is part of the source booking record and is used by queries. Cross-table checks verify that the type and subtype agree.

## 6. Delete rules

- **`RESTRICT` for reference/master data:** airlines, airports, customers, coupons, flights, hotels and room types cannot be deleted while referenced by operational records. This protects booking and travel history from accidental deletion.
- **`CASCADE` for dependent detail rows:** deleting a booking removes its flight or hotel detail row; deleting a flight-booking detail removes its passenger rows; deleting a hotel booking removes its review. These rows have no independent meaning without their parent booking/detail.
- The `hotel_reviews.hotel_id` reference uses `RESTRICT`, preserving the hotel record while reviews refer to it.

## 7. CHECK constraints implemented

The DDL includes more than 12 named `CHECK` constraints. They validate formats, allowed values, numeric ranges and date/time relationships.

| Constraint | Rule |
|---|---|
| `chk_airport_iata` | Airport code is three uppercase letters. |
| `chk_airport_country` | Country code is two uppercase letters. |
| `chk_airline_code` | Airline code is two or three uppercase letters/digits. |
| `chk_customer_email` | Email follows a basic `local@domain.tld` pattern. |
| `chk_customer_loyalty` | Loyalty tier is one of the four supported values. |
| `chk_coupon_applies` | Coupon applies to `ALL`, `FLIGHT` or `HOTEL`. |
| `chk_coupon_discount` | Discount percentage is greater than zero and at most 100. |
| `chk_coupon_max_discount` | Maximum discount is positive. |
| `chk_coupon_dates` | Coupon end date is not before its start date. |
| `chk_flight_number` | Flight number follows the selected code-and-three-digits pattern. |
| `chk_flight_route` | Origin and destination differ. |
| `chk_flight_time` | Arrival is later than departure. |
| `chk_flight_seats` | Total seats are positive. |
| `chk_flight_fare` | Base fare is positive. |
| `chk_flight_status` | Flight status is one of the five supported values. |
| `chk_hotel_star_rating` | Star rating is between 1 and 5. |
| `chk_hotel_user_rating` | User rating is NULL or between 1 and 5. |
| `chk_hotel_amenities` | Amenities JSONB value is an object. |
| `chk_room_max_guests` | Maximum guests is positive. |
| `chk_room_price` | Price per night is positive. |
| `chk_room_total` | Total rooms is positive. |
| `chk_booking_reference` | Booking reference is eight uppercase letters/digits. |
| `chk_booking_type` | Booking type is `FLIGHT` or `HOTEL`. |
| `chk_booking_amount` | Total amount is positive. |
| `chk_booking_discount` | Discount is between zero and total amount. |
| `chk_booking_coupon_discount` | A non-zero discount requires a coupon code. |
| `chk_booking_payment` | Payment method is one of the five supported values. |
| `chk_booking_status` | Booking status is one of the four supported values. |
| `chk_booking_cancellation` | Cancellation timestamp and refund are present exactly when status is `CANCELLED`. |
| `chk_booking_refund` | Refund is NULL or between zero and total amount. |
| `chk_flight_cabin` | Cabin is `ECONOMY`, `PREMIUM` or `BUSINESS`. |
| `chk_flight_passengers` | Passenger count is positive. |
| `chk_flight_fare_paid` | Fare paid is positive. |
| `chk_passenger_sequence` | Passenger sequence number is positive. |
| `chk_passenger_age` | Passenger age is non-negative. |
| `chk_passenger_gender` | Gender code is `M`, `F` or `X`. |
| `chk_passenger_seat` | Seat number is NULL or follows the selected row/letter pattern. |
| `chk_hotel_booking_dates` | Check-out is after check-in. |
| `chk_hotel_booking_rooms` | Number of rooms is positive. |
| `chk_hotel_booking_guests` | Number of guests is positive. |
| `chk_review_rating` | Review rating is between 1 and 5. |

`NOT NULL` and `UNIQUE` constraints are also used throughout the schema, as shown in the data dictionary. These constraints are separate from the `CHECK` constraints listed above.

## 8. Seed-data inspection and integrity checks

The supplied ZIP contains the following 12 CSV files. The row counts below were checked directly from the extracted CSV files.

| CSV / table | Expected rows from project brief | Rows inspected | Match |
|---|---:|---:|---|
| `airports` | 16 | 16 | Yes |
| `airlines` | 5 | 5 | Yes |
| `flights` | 13,848 | 13,848 | Yes |
| `hotels` | 3,000 | 3,000 | Yes |
| `room_types` | 9,000 | 9,000 | Yes |
| `customers` | 40,000 | 40,000 | Yes |
| `coupons` | 30 | 30 | Yes |
| `bookings` | 144,792 | 144,792 | Yes |
| `flight_bookings` | 84,899 | 84,899 | Yes |
| `passengers` | 163,380 | 163,380 | Yes |
| `hotel_bookings` | 59,893 | 59,893 | Yes |
| `hotel_reviews` | 15,913 | 15,913 | Yes |

### Integrity checks performed against the CSV data

These are pre-load checks performed against the supplied CSV files. They are not a substitute for running the SQL checks against the PostgreSQL database after `02_load_data.sql`; paste the actual PostgreSQL output here once the load is complete.

| Check | Result from CSV inspection |
|---|---|
| Primary-key and declared unique-key duplicates | No duplicates found for the checked keys: airport code, airline code/name, customer ID/email/phone, flight ID, booking ID/reference, flight-booking ID, hotel-booking ID, passenger `(booking_id, seq_no)`, and review ID/booking ID. |
| Foreign-key references | No orphan references found for airline, airport origin/destination, hotel, customer, coupon, flight, booking, passenger-to-flight-booking, hotel/room-type composite, or review references. |
| Booking subtype coverage | All 144,792 bookings have exactly one matching detail row: 84,899 flight bookings and 59,893 hotel bookings. No booking appears in both subtype tables and none is missing a subtype row. |
| Passenger count consistency | All 84,899 flight-booking `passengers` values equal the number of corresponding rows in `passengers`. |
| Booking cancellation fields | All cancelled bookings have both `cancelled_at` and `refund_amount`; all non-cancelled bookings have both fields NULL. |
| Hotel review consistency | All 15,913 reviews reference an existing hotel booking and hotel; the review's `hotel_id` matches the linked hotel booking's `hotel_id`. |
| Flight chronology | No flight has `arrival_at` earlier than or equal to `departure_at`; no flight booking in the seed data was made after that flight's departure. |
| Hotel stay dates | No hotel booking has `check_out` earlier than or equal to `check_in`. |
| Domain/range checks | The inspected values satisfy the DDL's airport/airline/flight/booking-reference formats, status and category sets, positive amount/count rules, rating ranges, and the passenger seat format. |

### Important scope note

The checks above establish that the inspected seed rows appear compatible with the constraints in the submitted DDL. The PostgreSQL load is the final test: execute `sql/01_schema.sql`, then `sql/02_load_data.sql`, and record the actual `COUNT(*)` and integrity-query outputs here. Cross-table rules such as booking subtype exclusivity, passenger-count equality, and matching hotel IDs across a review and its booking are not enforced by ordinary row-level `CHECK` constraints; they should remain explicit load-time integrity checks unless additional triggers are implemented.

## 9. Indexes in this checkpoint

No manually created performance indexes are added in Phase 2, as required by the project brief. PostgreSQL automatically creates indexes for the primary keys and unique constraints. These automatic indexes support key lookups and enforce uniqueness. Query-specific indexes will be considered only in the optimization phase after baseline measurements.

## 10. Conclusion

The proposed `mmt` schema represents the 12 supplied CSV entities, uses data types suited to identifiers, money, dates, timestamps, times and JSON amenities, and defines primary keys, foreign keys, uniqueness, nullability and validation constraints. The seed-data inspection matched all stated row counts and found no violations in the checks listed above. The remaining CP1 validation step is to run the team's PostgreSQL schema and load scripts and add the database-generated row-count and integrity-check output to this document.

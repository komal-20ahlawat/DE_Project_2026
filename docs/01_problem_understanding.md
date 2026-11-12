# 01. Problem Understanding

**Project:** MakeMyTrip Travel Booking Database
**Course:** Database Management Systems (DBMS)
**Team Number:** T0051
**Section:** B
**Database:** PostgreSQL 15 or newer

---

## 1. Business Context

MakeMyTrip provides two major services: flight bookings and hotel stays. Its database handles customer information, flight schedules, hotel details, bookings, passengers, payments, coupons and hotel reviews.

The existing database was developed without proper documentation, and only data exports are available. The primary objective of this project is to understand the business requirements, reconstruct a well-structured database schema, analyze query performance, optimize SQL queries and ensure scalability as booking volume increases.

## 2. Identified Business Problems

| ID                                          | Business Requirement                                                                                                                                                                                          | Affected Stakeholders               | Problem Classification                       |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | -------------------------------------------- |
| **P1 – Flight Search and Fare Calendar**    | Travellers need to search flights between airports, compare fares for different dates and view accurate seat availability. The system must return these results quickly.                                      | Traveller                           | Customer-facing / Real-time                  |
| **P2 – Hotel Search and Room Availability** | Users need to search hotels using city, star rating and amenity filters. They must also be able to check room availability for their selected stay dates.                                                     | Traveller, Hotel Partner            | Customer-facing / Real-time                  |
| **P3 – My Trips and Booking Lookup**        | Customers need quick access to upcoming trips, booking details through booking references and account information during sign-in.                                                                             | Traveller, Customer Support         | Customer-facing / Real-time                  |
| **P4 – Airline Manifests and Reports**      | Airline partners require passenger manifests for individual flights, along with low-load flight reports and cancellation-rate information for operational planning.                                           | Airline Partner, Revenue Management | Mixed: Operational and Reporting / Analytics |
| **P5 – Checkout and Payments**              | The system must efficiently process pending payments, booking confirmations, cancellations and refunds, even when multiple payment requests arrive simultaneously.                                            | Payments, Traveller                 | Customer-facing / Real-time                  |
| **P6 – Coupon Usage Analysis**              | The marketing team needs to identify coupons that have never been used to evaluate coupon adoption and marketing campaign performance.                                                                        | Marketing                           | Reporting / Analytics                        |
| **P7 – Hotel Room-Nights and Check-in**     | Hotel partners need reports showing room-nights sold per city, while front-desk staff require quick room-number assignment during customer check-in.                                                          | Hotel Partner, Front Desk           | Mixed: Reporting / Analytics and Operational |
| **P8 – Business Intelligence and Growth**   | Finance and loyalty teams require reports on revenue, booking lead time, repeat customers, last-minute bookings, popular routes and concessions. These reports must remain efficient as booking volume grows. | Revenue Management, Loyalty Team    | Reporting / Analytics                        |

## 3. Assumptions

1. **Operational queries:** Flight search, hotel search, room availability, My Trips, booking lookup, sign-in, checkout, payment confirmation, cancellations and room assignments are considered time-sensitive operations.

2. **Analytical queries:** Revenue analysis, coupon usage, cancellation rates, room-nights, customer trends, route analysis and loyalty reports are considered reporting workloads.

3. **Mixed workloads:** P4 includes operational passenger-manifest retrieval and analytical airline reports. P7 includes analytical room-nights reporting and operational room-number assignment.

4. **Booking structure:** According to the project requirements, every booking represents either a flight booking or a hotel booking. A flight booking can contain one or more passengers, whereas a hotel booking contains stay dates, room details and guest information.

5. **Data source:** The 12 CSV files provided in the project repository are considered the primary source for reconstructing the existing database. No unsupported business rules are assumed.

6. **Future scalability:** The database should be capable of handling approximately 20 times the current booking volume, as specified in the project requirements.

## 4. Conclusion

The MakeMyTrip database must support both fast operational transactions and reliable analytical reporting. Customer-facing operations require low response times, whereas analytical workloads must efficiently process larger volumes of booking and travel data.

Understanding these requirements provides the foundation for the upcoming phases, which involve database schema reconstruction, data loading, baseline query benchmarking, query optimization and scalability testing.

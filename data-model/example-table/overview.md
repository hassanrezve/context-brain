# Example table — `orders`

> Example entry. Record only what is easy to get wrong; the schema itself is in the migrations.

- `orders.total` is stored in **minor units** (pence/cents) as an integer. Never divide in SQL;
  format with the money helper. Verified against the migration and `Order` casts, 2026-01-10.
- `orders.customer_id` has **no foreign key** on purpose: orders are imported before customers in
  the nightly sync. Check for orphans with a join, not by trusting the database.
- `status` values live in the `OrderStatus` enum, not a lookup table.

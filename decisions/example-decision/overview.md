# Example decision — soft delete for customer records

> Example entry. Copy the shape, replace the content, delete this line.

**Status:** current. **Decided by:** product owner, 2026-01-12. **Recorded by:** the developer who
built it, same day.

## The decision

Customer records are soft-deleted (`deleted_at`), never removed. A deleted customer disappears from
every list and search but stays reachable from old invoices.

## Why

Invoices must keep showing the customer they were issued to for seven years (accounting rule).
Hard delete broke old invoice PDFs in testing.

## Rejected

- **Hard delete with a copied name on the invoice.** Loses the address and tax number the PDF needs.
- **An "archived" status flag.** Every existing query would need a new filter; `deleted_at` is
  already excluded by the framework by default.

## Consequences

- Unique checks on `email` must ignore soft-deleted rows, or a returning customer cannot sign up.
- Restoring a customer is an admin-only action.

## Open

- How long a soft-deleted customer is kept after the seven years: not decided, asked 2026-01-12.

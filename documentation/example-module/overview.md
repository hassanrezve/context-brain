# Example module — Invoices

> Example entry. One folder per module; split into sibling files when it grows.

## What it is

Where staff issue, send and void invoices. Customers see their own invoices in the portal.

## Where it lives

- Code: `app/Invoices/` (service, model, policies). UI: `resources/views/invoices/`.
- Tests: `tests/Feature/Invoices/`.

## Rules and decisions

- An issued invoice is never edited; it is voided and re-issued (owner, 2026-01-05). Reason:
  audit trail.
- Numbering is per company, gap-free: `INV-<year>-<sequence>`.

## Known gaps

- Credit notes are not built. Asked 2026-01-05, not scheduled.

# Module `budget`

Monthly AWS Budget (COST, USD) with email notifications at 80 % / 100 % actual and 100 % forecasted.
Optionally scoped to `Project=ticketing` (activate the tag as a cost allocation tag first).

Not applied in LocalStack (Budgets is not emulated by the community edition).

Outputs: `budget_name`.

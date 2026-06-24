# Legacy Data Import Rendering Plan

This document maps the uploaded AUM legacy exports into the CRM/ERP schema.

## Source Files

- `Quotation.csv`: legacy QuickBooks Estimate rows.
- `Invoices.csv`: legacy invoice, sales receipt, and credit memo rows.
- `Items.csv`: legacy item/service master list.
- `AumSmart Quotes - Google Sheets.pdf`: task-board snapshot with pending sites, quotations to make, priorities, follow-ups, invoices to make, collections, work done, visits, AMC, and approved items.

## Normalized Import Outputs

A normalized import bundle was generated with these files:

- `clients_import.csv`
- `quotations_import.csv`
- `invoices_import.csv`
- `invoice_items_import.csv`
- `credits_receipts_review.csv`
- `inventory_items_import.csv`
- `service_categories_seed.csv`
- `legacy_task_board_import.csv`
- `import_summary.json`

## Import Counts

```json
{
  "clients": 192,
  "quotations": 302,
  "quotation_total_value": 107766802.95,
  "invoice_headers": 345,
  "invoice_lines": 834,
  "invoice_total_value": 144753098.24,
  "inventory_items": 86,
  "service_categories": 12,
  "task_board_items": 140,
  "credit_or_receipt_rows_for_manual_review": 6
}
```

## Import Order

1. `service_categories_seed.csv`
2. `clients_import.csv`
3. `inventory_items_import.csv`
4. `quotations_import.csv`
5. `invoices_import.csv`
6. `invoice_items_import.csv`
7. `credits_receipts_review.csv`
8. `legacy_task_board_import.csv`

## Mapping to Current System

### Clients

Source:

- Quotation customer names
- Invoice customer names

Target:

- `clients.client_name`
- `clients.notes = Imported from QuickBooks legacy quotation/invoice exports`

Deduplication key:

- Uppercase normalized client name.

### Quotations

Source:

- `Quotation.csv` rows where `Type = Estimate`

Target:

- `quotations.quote_number = LEG-Q-{legacy Num}`
- `quotations.client_id = matched client`
- `quotations.project_name = Legacy quote {Num} - {Client}`
- `quotations.scope_of_supply = Imported from QuickBooks Estimate report`
- `quotations.subtotal = Amount`
- `quotations.vat_amount = 0`
- `quotations.grand_total = Amount`
- `quotations.status = SENT`

Note:

- The export does not contain item-level quotation details, so quotation headers should be imported first. Detailed quote item reconstruction can happen later if source itemized estimates are exported.

### Invoices

Source:

- `Invoices.csv` rows where `Type = Invoice`

Target:

- `invoices.invoice_number = LEG-INV-{legacy Num}`
- `invoices.client_id = matched client`
- `invoices.subtotal = sum(invoice line amounts)`
- `invoices.vat_amount = 0`
- `invoices.grand_total = sum(invoice line amounts)`
- `invoices.amount_paid = 0`
- `invoices.balance_due = grand_total`
- `invoices.status = SENT`

Note:

- Payment allocation is not clean in the provided invoice export. Credit memo and sales receipt rows are isolated into `credits_receipts_review.csv` for manual reconciliation before updating invoice balances.

### Invoice Items

Source:

- Invoice rows from `Invoices.csv`

Target:

- `invoice_items.invoice_id = matched invoice`
- `invoice_items.item_code = Item`
- `invoice_items.description = Memo`
- `invoice_items.quantity = Qty or 1`
- `invoice_items.unit_rate = Sales Price`
- `invoice_items.total_amount = Amount`

### Inventory Items

Source:

- `Items.csv`

Target:

- `inventory_items.sku = Item`
- `inventory_items.item_name = Description`
- `inventory_items.category = Type`
- `inventory_items.quantity_available = 0`
- `inventory_items.unit_cost = Cost`
- `inventory_items.selling_price = Price`
- `inventory_items.supplier = Preferred Supplier`

Note:

- These are mostly service items from the legacy export. Do not treat imported quantities as physical stock until stock movements exist.

### Service Categories

Source:

- Item categories and seeded AUM service lines.

Target:

- `service_categories.name`
- `service_categories.description`

### Task Board

Source:

- AumSmart Quotes task-board PDF.

Target:

- Render into `follow_ups`, `challenges`, and operational tasks depending on bucket.

Mapping:

- `Pending Sites` -> follow-up or site/project discovery task.
- `Quotation to Make` -> follow-up linked to lead/client when matched.
- `Priority` -> high-priority follow-up.
- `Lead Follow-up` -> sales follow-up.
- `Invoice to Make` -> finance follow-up.
- `Vasuli` -> collections follow-up.
- `Work Done` -> completion-proof or project closure review.
- `To Meet / Visit` -> meeting/site visit follow-up.
- `AMC` -> AMC follow-up.
- `Approved` -> completed/approved task record.

## Business Rules During Import

1. Never overwrite existing production records blindly.
2. Upsert by legacy number and client name.
3. Prefix imported document numbers with `LEG-` to avoid conflict with new counters.
4. Keep all legacy source references in notes or metadata.
5. Import credit memos and sales receipts into a review table/file first; reconcile them after finance confirms allocation.
6. Task-board entries should be imported as pending follow-ups, not as invoices or completed projects.

## Immediate Replit Action

Place the generated import bundle in the Replit project under:

```text
data/import/legacy-aum/
```

Then implement an import command:

```text
pnpm import:legacy-aum
```

or use the current Replit AI backend script runner to read the CSVs in the import order above and upsert records through the service layer.

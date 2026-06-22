# AMC Contract Format Specification for Codex

This document converts AUM Smart Tech's sample AMC contracts and inspection report format into a reusable system specification for implementation in the CRM.

## Source document patterns

### 1. CCTV Annual Maintenance Contract Proposal

Source pattern: `CCTV ANNUAL MAINTENANCE CONTRACT PROPOSAL`.

Core structure:

1. Header
   - AUM SMART TECH LTD branding
   - Document title
   - Agreement date
2. Agreement parties
   - Provider: Aum Smarttech Limited
   - Customer name
   - Customer site/location
3. Terms of agreement
   - Commencement date
   - Agreement period
   - Auto-renewal term
   - Annual charge adjustment with 30 days written notice
4. Maintenance and troubleshooting services
   - Support availability
   - Planned maintenance frequency
   - Equipment cleaning and alignment
   - Remote/on-site configuration management
   - Engineer deficiency notes and recommendations
   - Equipment recording/date/time/cabling/firmware checks
   - Replacement parts billed separately
   - Working hours: 8:00 AM to 5:30 PM on working days
5. Charges and payment terms
   - Equipment covered
   - Annual AMC amount
   - VAT handling
   - Payment terms
   - One-time service and call-out rates
   - Non-comprehensive material-cost exclusion
6. Guarantee and liability
   - Defects liability/free maintenance period for new/additional installations
   - Product warranty period
   - Exclusion for power surge/spike faults
   - Limitation of liability
7. Termination
   - Customer termination responsibility for remaining period payments
   - Provider termination with 30 days' prior notice
8. Signature block
   - Provider signature/name/date
   - Customer signature/name/date

### 2. Data / PoE / Wi-Fi / Networking / Intercom AMC

Source pattern: `ANNUAL MAINTENANCE CONTRACT FOR DATA / PoE / Wi-Fi - NETWORKING / INTERCOM`.

This follows the same legal and signature structure as the CCTV AMC, with different service scope and equipment coverage:

- Service category: Data / PoE / Wi-Fi / Networking / Intercom
- Devices: Unifi Access Points, Intercom Devices, and other networking equipment
- Planned maintenance: three services per year, once every four months
- Maintenance tasks include system updates, cabling checks, corrosion checks, and firmware upgrades for Unifi and Commax devices
- Payment can be annual or split across three visits after every four months
- Non-AMC troubleshooting and one-time service rates are captured separately

### 3. Electric Fence Inspection Report

Source pattern: `ELECTRIC FENCE SYSTEM INSPECTION REPORT`.

This is not an AMC contract but should be supported by the same ACMS document engine as a pre-AMC inspection/audit report.

Core structure:

1. Header
   - AUM SMART TECH LTD branding
   - Report title
   - Client
   - Site location
   - Inspection date
   - Prepared by
2. Executive summary
   - High-level description of inspection/audit performed
3. System details
   - Approximate asset/system length or quantity
   - Number of major devices/components
   - Brand
   - System type
4. Scope of inspection
   - Testing activities
   - Physical inspection activities
   - Fault tracing
   - Earthing/grounding inspection
   - Vegetation/interference inspection
   - Hardware condition assessment
5. Findings
   - Component condition
   - Voltage/test readings
   - Alarm/status behavior
   - Battery/power condition
   - Physical condition
   - Cabling/underground/HT cable condition
   - Earthing condition
6. Identified issues
   - Numbered issue list
7. Recommendations
   - Numbered corrective action list
8. Conclusion
   - Operational status
   - Main causes
   - Recommended rectification
   - Risk if not rectified
9. Site images
   - Captioned evidence photos

## CRM data model additions

Implement or extend the AMC module with these logical entities.

### amc_contracts

Recommended fields:

```text
id
tenant_id
client_id / customer_id
contract_number
contract_title
service_category
system_type
status
approval_status
contract_date
commencement_date
end_date
agreement_period_months
auto_renewal_period_months
renewal_enabled
adjustment_notice_days
working_hours_start
working_hours_end
working_days
maintenance_frequency_label
maintenance_visits_per_year
payment_terms
charge_amount
currency
vat_mode
vat_rate
vat_amount
grand_total
non_comprehensive
material_cost_excluded
one_time_service_rate
callout_rate
troubleshooting_rate
defects_liability_months
product_warranty_months
warranty_exclusions
liability_clause
termination_notice_days
provider_name
customer_signatory_name
provider_signed_at
customer_signed_at
created_by
created_at
updated_at
```

### amc_contract_assets

```text
id
contract_id
asset_type
brand
model
quantity
location
notes
```

Examples:

- CCTV: IP cameras, HD cameras, NVR, DVR
- Network/Intercom: Unifi APs, Commax intercom devices, networking equipment
- Electric fence: energizers, fence sections, earth rods, HT cable, fence wires, poles/posts

### amc_service_tasks

```text
id
contract_id
sort_order
task_title
task_description
is_standard
```

### amc_rates

```text
id
contract_id
rate_type
amount
currency
vat_mode
notes
```

Rate types:

- annual_amc
- one_time_service
- maintenance_callout
- troubleshooting_visit
- material_cost

### amc_inspection_reports

```text
id
tenant_id
client_id / customer_id
contract_id nullable
report_number
report_title
system_type
site_location
inspection_date
prepared_by
executive_summary
system_details jsonb
scope_items text[]
findings jsonb
identified_issues text[]
recommendations text[]
conclusion
created_by
created_at
updated_at
```

### amc_report_images

```text
id
report_id
caption
image_url
sort_order
created_at
```

## Template types to add

```text
cctv_amc_proposal
network_intercom_amc_contract
electric_fence_inspection_report
```

## Template variable schema

Codex should support rendering with this variable map:

```json
{
  "company": {
    "name": "AUM SMART TECH LTD",
    "phone": "+254 787 620914 / +254 728663988",
    "email": "info@aumsmart.co.ke",
    "website": "www.aumsmart.co.ke"
  },
  "contract": {
    "title": "CCTV ANNUAL MAINTENANCE CONTRACT PROPOSAL",
    "date": "1st June 2026",
    "commencementDate": "1st June 2026",
    "agreementPeriod": "One (1) year",
    "renewalPeriod": "One (1) year",
    "adjustmentNoticeDays": 30,
    "serviceCategory": "CCTV",
    "workingHours": "8:00 AM to 5:30 PM",
    "workingDays": "working days"
  },
  "provider": {
    "name": "Aum Smarttech Limited"
  },
  "customer": {
    "name": "Customer Name",
    "location": "Customer Site Location"
  },
  "assets": [
    {
      "assetType": "IP Camera",
      "quantity": 10,
      "location": "Workshop"
    }
  ],
  "serviceTasks": [
    "Technical support from customer service team and support engineers",
    "Three maintenance services once every four months",
    "Equipment cleaning and alignment",
    "Cabling wear, exposure, and corrosion checks",
    "Firmware upgrades"
  ],
  "charges": {
    "annualAmount": 25000,
    "vatRate": 0.16,
    "vatMode": "inclusive_or_exclusive",
    "grandTotal": 29000,
    "currency": "KES",
    "paymentTerms": "Annual maintenance charge to be paid in advance before commencement of work",
    "materialCostExcluded": true,
    "oneTimeServiceRate": 15000,
    "calloutRate": 2000,
    "troubleshootingRate": 4500
  },
  "legal": {
    "defectsLiabilityMonths": 6,
    "productWarrantyMonths": 12,
    "terminationNoticeDays": 30,
    "warrantyExclusions": ["power surge", "power spike"],
    "liabilityClause": "Provider is not liable for indirect or consequential damages."
  },
  "signatures": {
    "providerAuthorizedSignature": null,
    "providerName": null,
    "providerDate": null,
    "customerAuthorizedSignature": null,
    "customerName": null,
    "customerDate": null
  }
}
```

## Backend implementation requirements

Codex should implement:

1. Template registry
   - `server/src/templates/amcTemplates.js`
   - Exports template metadata and default task lists
2. Document generation service
   - `server/src/services/amcDocumentService.js`
   - Generates HTML/Markdown payloads from template variables
   - Later can be connected to PDF generation
3. AMC routes
   - `GET /api/amc-contracts/templates`
   - `POST /api/amc-contracts/:id/render`
   - `POST /api/amc-contracts/:id/inspection-report`
4. Frontend integration
   - Template selector in AMC contract form
   - Equipment/assets table
   - Service task checklist builder
   - Charges/rates section
   - Legal terms preview
   - Signature block preview
5. Codex should avoid hardcoding customer names from samples except as seed examples.

## Frontend UI sections

AMC Create/Edit screen should include:

1. Contract identity
   - Contract type
   - Contract title
   - Contract number
   - Customer
   - Site location
   - Service category
2. Term details
   - Agreement date
   - Commencement date
   - Agreement period
   - Auto-renewal period
   - Adjustment notice days
3. Assets covered
   - Asset type
   - Quantity
   - Brand/model
   - Location
4. Maintenance scope
   - Standard tasks loaded from selected template
   - Custom task editor
5. Charges
   - Annual charge
   - VAT mode/rate
   - Grand total
   - Call-out/one-time/troubleshooting rates
   - Payment terms
6. Legal terms
   - Warranty
   - Defects liability
   - Exclusions
   - Termination
7. Output preview
   - Provider/customer parties
   - Terms
   - Service scope
   - Charges
   - Signature block

## Seed templates

### CCTV AMC standard tasks

```text
Unlimited technical support from customer service team and support engineers.
Three maintenance services once every four months.
Equipment cleaning and camera alignments during maintenance.
On-site or remote configuration management.
Engineer to note deficiencies and recommend required work.
Scan hard drive periodically and verify that the system is recording.
Check correct date and time for recordings.
Check cabling for wear, exposed wires, and connector corrosion.
Upgrade HikVision NVR/DVR/cameras to latest firmware where applicable.
Replacement equipment, parts, and materials billed separately.
```

### Network / Intercom AMC standard tasks

```text
Technical support from customer service team and support engineers.
Three maintenance services once every four months.
Equipment cleaning and device alignments during maintenance.
On-site or remote configuration management.
Engineer to note deficiencies and recommend required work.
Scan system periodically and verify system is updated.
Check correct date and time.
Check cabling for wear, exposed wires, and connector corrosion.
Upgrade Unifi Wi-Fi Access Point Products and Commax Intercom Devices to latest firmware where applicable.
Replacement equipment, parts, and materials billed separately.
```

### Electric Fence Inspection scope items

```text
Energizer testing.
Fence voltage testing.
Sectional fault tracing.
Physical inspection of fence wires and posts.
Earthing inspection.
Vegetation interference inspection.
Fence hardware condition assessment.
```

## Acceptance criteria

Codex implementation is complete when:

1. Admin/support/sales/finance users can create AMC contracts from a selected template.
2. Users can add covered assets and standard/custom maintenance tasks.
3. Charges support VAT-inclusive and VAT-exclusive display.
4. The rendered contract preview follows the sample document order.
5. Inspection reports support findings, issues, recommendations, conclusion, and image captions.
6. Generated records respect tenant isolation and existing RLS.
7. Sample customer names are not hardcoded except in seed/demo records.

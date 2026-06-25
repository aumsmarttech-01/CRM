# AMC Approval, GPS Clock-In, and Handover Notes Build Plan

## Objective

Add an operational flow for approved AMC work:

1. AMC is approved.
2. Work order / visit is generated.
3. Technician clocks in at the site.
4. System captures GPS location and timestamp.
5. Technician completes work.
6. Technician leaves a handover note.
7. Client representative signs/approves handover.
8. AMC visit/work order can be closed.

## Reference Handover Format

The uploaded MCL Rabai handover note contains these fields:

- Client name
- Site name/location
- Date of completion
- Project description
- Active devices installed on site
- Client verification/approval text
- Client representative name
- Designation
- Signature
- Date
- Notes/comments

Use this structure as the first digital handover-note template.

## Backend Schema Additions

### 1. amc_approvals

Tracks approved AMC jobs before execution.

Fields:

- id
- tenant_id nullable initially
- amc_contract_id
- client_id
- site_id nullable
- approved_by_user_id
- approval_status: PENDING | APPROVED | REJECTED | CANCELLED
- approved_at
- notes
- created_at
- updated_at

### 2. site_attendance_events

GPS clock-in/out for site work.

Fields:

- id
- tenant_id nullable initially
- technician_id / employee_id
- user_id nullable
- project_id nullable
- work_order_id nullable
- amc_visit_id nullable
- client_id nullable
- site_id nullable
- event_type: CLOCK_IN | CLOCK_OUT | BREAK_START | BREAK_END
- latitude numeric(10,7)
- longitude numeric(10,7)
- accuracy_meters numeric(10,2)
- device_id
- device_timestamp
- server_timestamp
- address_label nullable
- distance_from_site_meters nullable
- within_site_radius boolean
- source: WEB | MOBILE | OFFLINE_SYNC
- notes
- created_at

### 3. handover_notes

Digital job handover document.

Fields:

- id
- tenant_id nullable initially
- handover_number
- client_id
- project_id nullable
- work_order_id nullable
- amc_visit_id nullable
- site_id nullable
- technician_id nullable
- client_name_snapshot
- site_name_snapshot
- project_description
- completion_date
- devices_installed jsonb
- work_summary
- notes_comments
- client_representative_name
- client_representative_designation
- client_signature_data_url nullable
- technician_signature_data_url nullable
- approval_status: DRAFT | SUBMITTED | CLIENT_APPROVED | REJECTED
- approved_at
- pdf_url nullable
- created_by
- created_at
- updated_at

### 4. handover_note_items

Optional line-item device/equipment list.

Fields:

- id
- handover_note_id
- item_name
- description
- quantity
- serial_number nullable
- condition
- notes
- created_at

## Backend API

### AMC Approval

- `POST /api/amc/:contractId/approve`
- `GET /api/amc/approved`
- `POST /api/amc/:contractId/create-visit-from-approval`

Rules:

- Only ADMIN / EXECUTIVE / authorized operations roles can approve AMC.
- Approval should create or link to an AMC visit/work order.
- Audit log every approval/rejection.

### GPS Site Clock-In

- `POST /api/site-attendance/clock-in`
- `POST /api/site-attendance/clock-out`
- `GET /api/site-attendance/my-today`
- `GET /api/site-attendance/by-work-order/:workOrderId`
- `GET /api/site-attendance/by-amc-visit/:amcVisitId`

Request body:

```json
{
  "workOrderId": "optional",
  "amcVisitId": "optional",
  "siteId": "optional",
  "latitude": -4.05,
  "longitude": 39.66,
  "accuracyMeters": 12,
  "deviceId": "browser-or-mobile-device-id",
  "deviceTimestamp": "2026-06-24T09:30:00.000Z",
  "notes": "Arrived on site"
}
```

Rules:

- Technicians can only clock into assigned work.
- Capture browser/mobile GPS via frontend Geolocation API.
- Compare captured coordinates against site coordinates if available.
- Mark `within_site_radius = true` when distance is within the configured radius.
- If GPS permission is denied, allow manual note only if manager override is enabled.
- Audit log clock-in/out events.

### Handover Notes

- `POST /api/handover-notes`
- `GET /api/handover-notes/:id`
- `PATCH /api/handover-notes/:id`
- `POST /api/handover-notes/:id/submit`
- `POST /api/handover-notes/:id/client-approve`
- `GET /api/handover-notes/by-work-order/:workOrderId`
- `GET /api/handover-notes/by-amc-visit/:amcVisitId`

Rules:

- Handover note required before closing work order or AMC visit if the job type requires handover.
- Client signature should be captured on frontend canvas.
- PDF generation can be added after MVP; store structured data first.
- Audit log submission and client approval.

## Frontend Pages

### Technician My Work

Enhance `/my-work`:

For each assigned work order / AMC visit:

- Clock In button
- Clock Out button
- View location status
- Start Handover Note
- Submit Handover Note

Use browser geolocation:

```ts
navigator.geolocation.getCurrentPosition(success, error, {
  enableHighAccuracy: true,
  timeout: 15000,
  maximumAge: 30000,
});
```

### AMC Approved Work Page

Add:

- `/amc/approved`

Show:

- Approved AMC contracts/visits
- Client
- Site
- Assigned technician
- Visit status
- Clock-in status
- Handover status

### Handover Note Form

Add:

- `/handover-notes/new?workOrderId=...`
- `/handover-notes/new?amcVisitId=...`
- `/handover-notes/:id`

Fields based on MCL Rabai handover:

- Client name
- Site name/location
- Completion date
- Project description
- Devices installed
- Work summary
- Notes/comments
- Client representative name
- Designation
- Client signature
- Technician signature

## Closure Rules

A work order or AMC visit cannot be closed until:

1. Technician clocked in.
2. Technician clocked out.
3. Handover note submitted.
4. Client handover approved/signed, unless manager override is applied.
5. Completion proof exists where required.
6. Critical compliance items are closed.

## Replit Implementation Prompt

```text
Build AMC approval, GPS technician clock-in, and digital handover notes.

Reference the uploaded MCL Rabai handover note format.

Backend:
1. Add Drizzle schemas:
   - amc_approvals
   - site_attendance_events
   - handover_notes
   - handover_note_items

2. Export schemas from schema index.

3. Add routes:
   - artifacts/api-server/src/routes/amc-approvals.ts
   - artifacts/api-server/src/routes/site-attendance.ts
   - artifacts/api-server/src/routes/handover-notes.ts

4. Add services:
   - artifacts/api-server/src/services/site-attendance.service.ts
   - artifacts/api-server/src/services/handover-note.service.ts
   - artifacts/api-server/src/services/amc-approval.service.ts

5. Mount routes in routes/index.ts with authentication and capability gates.

6. Enforce:
   - technicians can only clock into assigned work
   - GPS coordinates are captured
   - distance from site is calculated when site coordinates exist
   - handover note is required before work order / AMC visit closure
   - audit logs are written for approval, clock-in, clock-out, submit handover, client approval

Frontend:
1. Enhance /my-work:
   - Clock In
   - Clock Out
   - Start Handover
   - Handover Status

2. Add pages:
   - /amc/approved
   - /handover-notes/new
   - /handover-notes/:id

3. Add browser geolocation helper:
   - request current GPS location
   - show permission errors clearly
   - send latitude, longitude, accuracyMeters, deviceTimestamp

4. Add handover note form using the MCL Rabai structure:
   - client
   - site/location
   - completion date
   - project description
   - active devices installed
   - client representative name
   - designation
   - signature
   - notes/comments

5. Add signature capture canvas for client approval.

Tests/verification:
- technician cannot clock into unassigned work
- assigned technician can clock in/out
- closure fails without handover note
- closure succeeds after handover approval
- audit logs are created

Run:
- pnpm run typecheck
- pnpm run build
- pnpm --filter @workspace/db run push

Return:
STATUS:
FILES CREATED:
FILES MODIFIED:
DATABASE CHANGES:
COMMANDS RUN:
RESULTS:
BLOCKERS:
```

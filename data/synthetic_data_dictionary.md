# Data dictionary — College Admissions & Enrollment Monitoring

## Dataset status
All records are **synthetic and fictional**. They do not come from La Cité, any Canadian college, or real students. Identifiers are randomly generated labels and contain no personal information.

## Grain and structure
Each CSV in `data/raw/` is a weekly snapshot. A snapshot contains applications received on or before its snapshot date, with statuses as represented at that date. The same `application_id` can appear in multiple weekly files. This is intentional and supports week-over-week monitoring.

There are 12 weekly snapshots, from 2026-08-31 through 2026-11-16.

## Fields
| Field | Type | Description |
|---|---|---|
| `application_id` | string | Unique identifier for an application; stable across snapshots. |
| `student_id` | string | Synthetic student identifier; one student may have multiple applications. |
| `application_date` | date | Date the application was submitted. |
| `academic_year` | string | Academic year associated with the application. |
| `program` | string | Program applied to. |
| `study_level` | string | Credential/study level. |
| `application_status` | string | Submitted, Under Review, Decision Issued, or Withdrawn. |
| `admission_decision` | string | Pending, Admitted, Rejected, Waitlisted, or Withdrawn. |
| `registration_status` | string | Registered, Declined, Pending, or Not Applicable. |
| `processing_days` | integer / missing | Calendar days between application and admission decision; missing if no decision is available. |
| `application_channel` | string | Channel through which the application was submitted. |
| `weekly_snapshot` | date | Date on which the weekly extract was produced. |

## Controlled data-quality issues
Raw extracts intentionally contain a small number of issues:
- Missing values in `program`.
- Missing values in `application_channel`.
- A small number of unusually high `processing_days` values (95–150 days), to investigate as potential outliers.
- A very small number of exact duplicate rows within each weekly extract.

These are deliberate teaching examples. Assess and document their impact before changing or removing records.

## Analytical cautions
- Do not sum application counts across weekly snapshots: applications repeat over time.
- For a point-in-time count, use one snapshot only.
- For longitudinal analysis, compare snapshots using `application_id`.
- `processing_days` is measured in calendar days, not business days.
- This is a simulated portfolio dataset, not an official institutional dataset.

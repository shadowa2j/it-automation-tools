# Monthly Billing Report Instructions

## Setup (One-Time)

1. Create a folder on your computer:
   ```
   C:\Reports\Billing
   ```

2. Save the two PowerShell scripts to this folder:
   - `Convert-BillingReportToHtml.ps1`
   - `Compare-BillingReports.ps1`

---

## Monthly Process

### Step 1: Save the CSV

1. Open the email containing the billing report
2. Save the CSV attachment to: `C:\Reports\Billing`
3. Rename the file using this exact format:
   ```
   Billing_Report_YYYY-MM.csv
   ```
   
   **Examples:**
   - January 2026 → `Billing_Report_2026-01.csv`
   - February 2026 → `Billing_Report_2026-02.csv`
   - December 2025 → `Billing_Report_2025-12.csv`

   > **Important:** Use the 2-digit month (01-12), not the month name.

---

### Step 2: Generate the Monthly Report

1. Open PowerShell
2. Run this command (copy/paste):
   ```powershell
   C:\Reports\Billing\Convert-BillingReportToHtml.ps1 -CsvPath "C:\Reports\Billing\Billing_Report_YYYY-MM.csv" -OutputPath "C:\Reports\Billing\BillingReport_YYYY-MM.html"
   ```
   
   > Replace `YYYY-MM` with the current month (e.g., `2026-01`)

3. Open the generated HTML file to view the report

---

### Step 3: Generate the Comparison Report (Month 2+)

Once you have at least 2 months of reports saved:

1. Open PowerShell
2. Run this command (copy/paste):
   ```powershell
   C:\Reports\Billing\Compare-BillingReports.ps1 -FolderPath "C:\Reports\Billing" -OutputPath "C:\Reports\Billing\BillingComparison.html"
   ```

3. The script automatically finds the two most recent reports and compares them

4. Open `BillingComparison.html` to view changes

---

## Folder Structure Example

After a few months, your folder should look like:

```
C:\Reports\Billing\
├── Convert-BillingReportToHtml.ps1
├── Compare-BillingReports.ps1
├── Billing_Report_2025-12.csv
├── Billing_Report_2026-01.csv
├── Billing_Report_2026-02.csv
├── BillingReport_2025-12.html
├── BillingReport_2026-01.html
├── BillingReport_2026-02.html
└── BillingComparison.html
```

---

## Quick Reference

| Month | CSV Filename |
|-------|--------------|
| January | `Billing_Report_YYYY-01.csv` |
| February | `Billing_Report_YYYY-02.csv` |
| March | `Billing_Report_YYYY-03.csv` |
| April | `Billing_Report_YYYY-04.csv` |
| May | `Billing_Report_YYYY-05.csv` |
| June | `Billing_Report_YYYY-06.csv` |
| July | `Billing_Report_YYYY-07.csv` |
| August | `Billing_Report_YYYY-08.csv` |
| September | `Billing_Report_YYYY-09.csv` |
| October | `Billing_Report_YYYY-10.csv` |
| November | `Billing_Report_YYYY-11.csv` |
| December | `Billing_Report_YYYY-12.csv` |

---

## Troubleshooting

**"Script cannot be loaded because running scripts is disabled"**
Run this once in PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"Need at least 2 billing reports in folder"**
The comparison script requires 2+ months of data. This is normal for the first month.

**Report shows no data**
Check that the CSV filename follows the exact format: `Billing_Report_YYYY-MM.csv`

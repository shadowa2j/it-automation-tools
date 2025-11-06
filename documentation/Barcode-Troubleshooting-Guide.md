# Crystal Reports Barcode Decodability Issues with Zebra Printers

**Author:** Bryan Faulkner  
**Category:** Troubleshooting Guide  
**Last Updated:** 2025-11-06

## Summary
Decodability issues on AIAG B-10 or Code 128 labels from Crystal Reports to Zebra printers almost always come from scaling, driver compression, or rasterization settings. This guide walks through identifying the print method, adjusting driver settings, and testing for proper barcode quality.

---

## Step 1: Identify How They're Printing

There are two main ways Crystal Reports sends print data to a Zebra:

1. Using the Zebra driver in Windows (e.g. ZDesigner ZT230 (300 dpi)).
2. Using the Generic/Text Only or Zebra ZPL driver (raw ZPL pass-through).

Scaling and decodability only apply when the report is being rendered as a Windows graphic (option #1). If they're using raw ZPL, scaling happens inside Crystal's layout and not the driver.

Have them confirm in the Printer Name field of the dialog box which driver is selected.

---

## Step 2: Open the Printer Properties from the Crystal Dialog

From the Crystal Reports "Print" dialog:

1. Choose the Zebra printer in the list.
2. Click [Printer Properties] (not Page Setup).
3. The Zebra driver dialog should open. Depending on driver version:

### For ZDesigner Driver (Zebra Windows Driver v8 or v5)

* Go to the Options or Advanced Setup tab.
* Look for these fields:
   * Scaling or Print scaling mode → set to None or Actual Size.
   * Orientation Handling → keep Portrait if label is portrait.
   * Graphics Mode → choose Use printer fonts and barcodes if possible.
   * Media Settings → Width/Length → must match label stock (e.g. 4.00 in × 2.00 in).
* Click Apply / OK.

### For Generic/Text Only Driver

* There is no scaling option; Crystal rasterizes everything, which reduces barcode quality. Recommend switching to the ZDesigner driver.

---

## Step 3: Confirm Crystal's "Dissociate Formatting Page Size from Printer Settings"

Inside Crystal Reports Designer (for the report template):

1. Open the `.rpt`.
2. Go to File → Page Setup.
3. Uncheck "Dissociate formatting page size and printer paper size."
   * This ensures Crystal sends the correct dot dimensions instead of re-rendering to Windows DPI.
4. Ensure the paper size matches the physical label size (e.g. Custom 4.00 × 2.00 in).
5. Save and re-test.

---

## Step 4: Printer Defaults in Windows

Even if they can't see scaling in the Crystal dialog:

1. Have them open Windows → Printers & Scanners → ZDesigner ZT230 → Printer Properties → Preferences.
2. Under Advanced Setup, check:
   * Scaling: None or Actual Size
   * Resolution: match the printer (203 dpi / 300 dpi)
   * Darkness: match your validated grade (typically 25–30 for ZT230)
   * Print Speed: not higher than 3 in/s for barcode grade testing

Those defaults apply even when Crystal hides the dialog.

---

## Step 5: Test for Decodability

After fixing scaling, have them:

* Print one label and verify in RJS Inspector D4000 or verifier:
   * Decodability ≥ 0.5 (Grade C or better)
   * Edge Contrast ≥ 15 %
* If it's still low, reduce Print Speed or increase Darkness incrementally.

---

## Pro Tip for Troubleshooting

If you're troubleshooting many Zebra + Crystal setups:

* Ask customers to export the report to PDF and print from Adobe Reader at Actual Size — this isolates Crystal rendering vs driver scaling.
* If the PDF prints correctly, the issue is definitely in the Zebra driver's scaling or Windows DPI mismatch.

---

## Common Issues and Solutions

| Issue | Likely Cause | Solution |
|-------|-------------|----------|
| Barcode won't scan | Scaling enabled | Disable scaling in printer properties |
| Low decodability grade | Print speed too high | Reduce to ≤3 in/s |
| Poor edge contrast | Darkness too low | Increase darkness to 25-30 |
| Inconsistent quality | Page size mismatch | Match Crystal page size to label stock |

---

## Testing Checklist

- [ ] Verified printer driver in use (ZDesigner vs Generic)
- [ ] Disabled scaling in printer properties
- [ ] Unchecked "Dissociate formatting" in Crystal
- [ ] Matched paper size to label stock
- [ ] Set darkness to 25-30
- [ ] Set print speed to ≤3 in/s
- [ ] Tested with barcode verifier
- [ ] Achieved decodability ≥0.5
- [ ] Achieved edge contrast ≥15%

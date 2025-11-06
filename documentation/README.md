# Documentation

Technical documentation, troubleshooting guides, and knowledge base articles.

## Documents

### Barcode-Troubleshooting-Guide.md
**Category:** Troubleshooting Guide  
**Author:** Bryan Faulkner  
**Last Updated:** November 6, 2025

#### Overview
Comprehensive guide for resolving barcode decodability issues when printing AIAG B-10 or Code 128 labels from Crystal Reports to Zebra printers.

#### Topics Covered
1. **Print Method Identification**
   - ZDesigner driver vs. Generic/Text Only
   - Understanding Windows graphic rendering
   - Raw ZPL pass-through methods

2. **Driver Configuration**
   - Scaling settings (critical for barcode quality)
   - Graphics mode options
   - Media settings and label stock matching
   - Resolution and DPI configuration

3. **Crystal Reports Settings**
   - Dissociate formatting page size option
   - Page setup configuration
   - Paper size matching

4. **Windows Printer Defaults**
   - System-level printer preferences
   - Darkness settings (25-30 recommended)
   - Print speed optimization (≤3 in/s for testing)

5. **Quality Testing**
   - Decodability measurements (≥0.5 target)
   - Edge contrast requirements (≥15%)
   - Barcode verifier usage

#### Target Audience
- IT support staff troubleshooting printer issues
- Users setting up Crystal Reports for label printing
- Technicians configuring Zebra printers

#### Common Issues Addressed
| Issue | Solution |
|-------|----------|
| Barcode won't scan | Disable scaling in driver |
| Low decodability | Reduce print speed |
| Poor edge contrast | Increase darkness setting |
| Inconsistent quality | Match page size to label stock |

#### Testing Equipment Referenced
- RJS Inspector D4000 barcode verifier
- Zebra ZT230 printer series
- Crystal Reports (various versions)

#### Key Recommendations
- Always test with barcode verifier after changes
- Export to PDF and print from Adobe Reader to isolate issues
- Document working configurations for reference

---

## Document Types

This folder contains various types of documentation:
- 📘 **Troubleshooting Guides** - Step-by-step problem resolution
- 📗 **Knowledge Base Articles** - Formatted for internal KB systems (Hudu, etc.)
- 📕 **Technical References** - Detailed technical specifications
- 📙 **Best Practices** - Recommended approaches and standards

---

## Usage

### For IT Support Staff
These documents are designed to be:
- Quick reference guides during support calls
- Training materials for new team members
- Copy-paste ready for KB systems

### For End Users
Documents include:
- Clear, non-technical explanations where appropriate
- Step-by-step instructions with screenshots (where applicable)
- Common issue checklists

---

## Contributing New Documentation

When adding new documents:
1. Use Markdown format (.md)
2. Include document metadata:
   - Category
   - Author
   - Last Updated date
3. Add clear section headers
4. Include a summary/overview
5. Provide examples where applicable
6. Add to this README with brief description

---

## Related Resources

- **Prism Plastics** - Primary environment for barcode troubleshooting
- **Wilbert Plastics** - Terminal server documentation
- **Uplift Michigan** - Student onboarding process documentation

---

**Folder Version:** 1.0.0  
**Last Updated:** November 6, 2025  
**Maintainer:** Bryan Faulkner

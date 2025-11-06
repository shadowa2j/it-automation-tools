# Email Templates

HTML email templates for Uplift Michigan Online School student onboarding process.

## Templates

### UMOS-Welcome-Email.html
**Purpose:** New student and guardian welcome email with account credentials

**Features:**
- Student and guardian Accelerate account credentials
- Student email account information
- Links to important documents (attendance policies, Chromebook guide, login instructions)
- Mobile-responsive design
- Professional, friendly formatting

**Variables Used:**
- `$CFUMOSRewstGuardianFirstname` - Guardian's first name
- `$CFUMOSRewstStudentFirstname` - Student's first name
- `$CFUMOSRewstStudentLastname` - Student's last name
- `$CFUMOSRewstGuardianLastname` - Guardian's last name
- `$CFUMOSRewstStudentEmailAddress` - Student's email address

**Standard Password:** UMOSWelcome1 (must be changed on first login)

---

### UMOS-Chromebook-Shipping.html
**Purpose:** Chromebook shipping notification with tracking information

**Features:**
- Asset tag display
- Shipping carrier information
- USPS tracking link (clickable)
- Mobile-responsive design
- 24-hour tracking activation notice

**Variables Used:**
- `$CFUMOSRewstStudentFirstname` - Student's first name
- `$CFUMOSRewstStudentLastname` - Student's last name
- `$CFUMOSRewstAssignedAsset` - Chromebook asset tag
- `$CFUMOSRewstShippingCompany` - Shipping carrier name
- `$CFUMOSRewstTrackingNumber` - USPS tracking number

**Tracking URL Format:** `https://tools.usps.com/go/TrackConfirmAction?tLabels={TrackingNumber}`

---

## Usage

### In Rewst Workflows
1. Copy the HTML template content
2. Use as email body in Send Email action
3. Ensure all variables are populated in workflow context
4. Variables will be automatically replaced with actual values

### Testing
Before deploying, test with sample data:
```
$CFUMOSRewstStudentFirstname = "John"
$CFUMOSRewstStudentLastname = "Doe"
$CFUMOSRewstStudentEmailAddress = "john.doe@uplift-mi.org"
```

---

## Support Contact

**QCS Support:**
- Email: support@qcsph.com
- Phone: 888-956-6066

---

## Design Notes

### Mobile Responsiveness
Both templates include media queries for screens ≤600px:
- Reduced padding for better mobile display
- Adjusted font sizes
- Touch-friendly link targets (44px minimum)

### Email Client Compatibility
- Inline CSS for maximum compatibility
- Tested with major email clients
- Fallback styles for older clients

---

**Version:** 1.0.0  
**Author:** Bryan Faulkner  
**Last Updated:** November 5, 2025

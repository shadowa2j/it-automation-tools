# Email Templates

HTML email templates for HaloPSA, used across UMOS (Uplift Michigan Online School) and generic client workflows.

---

## UMOS Templates

### UMOS-Welcome-Email.html
**Purpose:** New student and guardian welcome email with account credentials

**Features:**
- Student and guardian Accelerate account credentials
- Student email account information
- Links to important documents (attendance policies, Chromebook guide, login instructions)
- Mobile-responsive design with UMOS branding

**Variables Used:**
- `$CFUMOSRewstGuardianFirstname` / `$CFUMOSRewstGuardianLastname` - Guardian name
- `$CFUMOSRewstStudentFirstname` / `$CFUMOSRewstStudentLastname` - Student name
- `$CFUMOSRewstStudentEmailAddress` - Student email address

**Standard Password:** UMOSWelcome1 (must be changed on first login)

---

### UMOS-Chromebook-Shipping.html
**Purpose:** Initial Chromebook shipping notification with tracking information

**Features:**
- Asset tag and shipping carrier display
- USPS tracking link (clickable)
- Optional additional info field
- 24-hour tracking activation notice

**Variables Used:**
- `$CFUMOSRewstStudentFirstname` / `$CFUMOSRewstStudentLastname` - Student name
- `$CFUMOSRewstAssignedAsset` - Chromebook asset tag
- `$CFUMOSRewstShippingCompany` - Shipping carrier name
- `$CFRewstTrackingNumberMulti` - Tracking number(s)
- `$CFAdditionalInfo` - Optional additional information

---

### UMOS-Tracking-Update.html
**Purpose:** Recurring 24-hour tracking update sent until delivery is confirmed

**Features:**
- Dynamic status message via `$CFRewstTrackingMessage`
- Detailed tracking info with scan events via `$CFRewstTrackingDetails`
- Works for all statuses (in transit, delivered, exception, etc.)
- Last updated timestamp

**Variables Used:**
- `$CFUMOSRewstStudentFirstname` / `$CFUMOSRewstStudentLastname` - Student name
- `$CFUMOSRewstAssignedAsset` - Chromebook asset tag
- `$CFRewstTrackingNumberMulti` - Tracking number(s)
- `$CFRewstTrackingMessage` - Friendly status message
- `$CFRewstTrackingDetails` - Pre-formatted HTML tracking details
- `$CFRewstTrackingLastUpdate` - Timestamp of last tracking check

---

### UMOS-Repair-Return.html
**Purpose:** Return shipping instructions for Chromebook repairs

**Features:**
- OneDrive shipping label link with download instructions
- Step-by-step packing and shipping guide
- Aggressive charger reminder (red warning box)
- USPS pickup scheduler link
- "What Happens Next" section

**Variables Used:**
- `$firstname` - Halo built-in user first name
- `$CFUMOSRewstAssignedAsset` - Chromebook asset tag
- `$CFShippingLabelLink` - OneDrive link to prepaid return label

---

### UMOS-Withdrawal-Return.html
**Purpose:** Equipment return instructions for withdrawn students

**Features:**
- Professional withdrawal notification language
- OneDrive shipping label link with download instructions
- Aggressive charger reminder (red warning box)
- MiFi hotspot return note (if assigned)
- Optional additional info field
- USPS pickup scheduler link

**Variables Used:**
- `$CFUMOSRewstStudentFirstname` / `$CFUMOSRewstStudentLastname` - Student name
- `$CFShippingLabelLink` - OneDrive link to prepaid return label
- `$CFAdditionalInfo` - Optional additional information

---

## Generic Templates

### Generic-Shipment-Notification.html
**Purpose:** Initial shipment notification for non-UMOS clients

**Features:**
- Minimal, clean formatting (no branding/boxes)
- Carrier-agnostic (no tracking links)
- Multi-package compatible language
- Optional additional info field

**Variables Used:**
- `$firstname` - Halo built-in user first name
- `$faultid` - Ticket number
- `$symptom` - Ticket summary
- `$CFUMOSRewstShippingCompany` - Shipping carrier name
- `$CFRewstTrackingNumberMulti` - Tracking number(s)
- `$CFADDITIONALINFO` - Optional additional information

---

### Generic-Shipping-Update.html
**Purpose:** Recurring shipping status update for non-UMOS clients

**Features:**
- Minimal, clean formatting (no branding/boxes)
- Dynamic status message and detailed tracking info
- Multi-package compatible
- Last updated timestamp

**Variables Used:**
- `$firstname` - Halo built-in user first name
- `$faultid` - Ticket number
- `$symptom` - Ticket summary
- `$CFRewstTrackingMessage` - Friendly status message
- `$CFRewstTrackingDetails` - Pre-formatted HTML tracking details
- `$CFRewstTrackingLastUpdate` - Timestamp of last tracking check

---

## Usage

### In Halo Email Templates
1. Create a new email template in HaloPSA
2. Add a custom HTML block (Unlayer editor)
3. Paste the template HTML into the block
4. Variables are automatically substituted by Halo at send time

### In Rewst Workflows
1. Use as email body in Send Email action
2. Ensure all custom field variables are populated in workflow context

---

## Design Notes

### UMOS Templates
- UMOS blue branding (`#0066cc`)
- Warning yellow (`#fff3cd` / `#ffc107`) for notices
- Red (`#f8d7da` / `#dc3545`) for critical warnings (charger reminders)
- Green (`#d4edda` / `#28a745`) for next steps
- Mobile-responsive with media queries for screens ≤600px
- Touch-friendly link targets (44px minimum)

### Generic Templates
- No colored boxes or backgrounds
- Simple horizontal rules between sections
- Monospace font for tracking numbers
- Minimal inline styling

### Email Client Compatibility
- All styling is inline CSS for maximum compatibility
- No external stylesheets or JavaScript
- Tested with major email clients

---

## Support Contact

**QCS Support:**
- Email: support@qcsph.com
- Phone: 888-956-6066

---

**Author:** Bryan Faulkner  
**Last Updated:** February 13, 2026

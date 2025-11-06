# Rewst Workflow Templates

Jinja templates and HTML reports for Rewst workflow automation, primarily for Uplift Michigan Online School student information management.

## Files

### Student-Guardian-Data-Parser.jinja
**Purpose:** Parses Skyward API responses to extract student and primary guardian information

**Input Requirements:**
- `CTX.input_first_name` - Student's first name for matching
- `CTX.input_last_name` - Student's last name for matching
- `CTX.all_students` - Array of students from Skyward SMS API
- `CTX.guardians_list` - Array of guardians from Skyward SMS API

**Output:** JSON object containing:
```json
{
  "success": true,
  "student": {
    "first_name": "string",
    "last_name": "string",
    "graduation_year": number,
    "student_id": number,
    "display_id": "string",
    "default_school_id": "string"
  },
  "primary_guardian": {
    "guardian_id": number,
    "first_name": "string",
    "last_name": "string",
    "full_name": "string",
    "email": "string",
    "phone_number": "string",
    "mailing_address": {
      "street": "string",
      "city": "string",
      "state": "string",
      "zip_code": "string",
      "full_address": "string",
      "address_type": "mailing|physical"
    }
  },
  "retrieved_at": "timestamp"
}
```

**Key Features:**
- Case-insensitive name matching
- Trims whitespace from input
- Identifies primary guardian by FamilyOrderNumber = 1
- Prefers mailing address over physical address
- Handles missing data gracefully

**Usage in Rewst:**
1. Create a NOOP action with Data Alias
2. Paste this Jinja template
3. Outputs to `CTX.parsed_skyward`
4. May need additional parsing step: `{{ CTX.parsed_skyward | from_json_string }}`

---

### Accelerate-Account-Status-Report.html
**Purpose:** Generates HTML report for student and guardian account creation status

**Input Requirements:**
- `CTX.parsed_skyward` - Parsed Skyward data (from above template)
- `CTX.accelerate_create_student_results` - Student account creation API response
- `CTX.accelerate_create_guardian_results` - Guardian account creation API response

**Features:**
- Color-coded status sections
- Detailed account status messages
- Handles existing vs. new accounts
- Shows inactive account reactivation
- Includes contact information and mailing address

**Account Status Logic:**
- `flags == 0` - Account exists and is active
- `flags == 2` - Account existed but was inactive (reactivated)
- `no user found` - New account created
- `response code != OK` - Error occurred

**Standard Credentials:**
- Username pattern: `firstname.lastname`
- Initial password: `UMOSWelcome1`
- Student email: `firstname.lastname@uplift-mi.org`

---

## Workflow Integration

### Typical Rewst Workflow Structure:

1. **Get Webhook Data** - Receive student information from HaloPSA
2. **Extract Student Name** - Parse first/last name from ticket
3. **Get All Students** - Skyward SMS API call
4. **Get All Guardians** - Skyward SMS API call
5. **Parse Skyward Data** - Use Student-Guardian-Data-Parser.jinja
6. **Parse JSON Result** - Convert string to object if needed
7. **Create Student Account** - Accelerate API call
8. **Create Guardian Account** - Accelerate API call
9. **Create Email Account** - Google Workspace API call
10. **Generate Report** - Use Accelerate-Account-Status-Report.html
11. **Send Report Email** - Email report to support team

### Common Issues

**Issue:** `CTX.parsed_skyward.student.first_name` returns "dict object has no attribute 'student'"

**Solution:** Add a parsing step after the Jinja template:
```jinja
{{ CTX.parsed_skyward | trim | from_json_string }}
```

**Issue:** Guardian not found or wrong guardian selected

**Solution:** Verify FamilyOrderNumber field in Skyward data - this identifies the primary family contact (usually = 1)

---

## API Integration Notes

### Skyward SMS API
- Returns student and guardian data
- Requires OAuth 2.0 authentication
- BaseURL: `https://skyward.iscorp.com/APIupliftacamiSTU`

### Accelerate API
- Used for student/guardian account creation
- Response includes user ID and flags
- Username format: `firstname.lastname`

---

## Testing

### Sample Test Data:
```jinja
CTX.input_first_name = "Lisbeth"
CTX.input_last_name = "Adon"
```

Expected output should include:
- Student graduation year
- Primary guardian email
- Mailing address with street, city, state, zip

---

**Version:** 1.0.0  
**Author:** Bryan Faulkner, with assistance from Claude  
**Last Updated:** November 3, 2025  
**Environment:** Uplift Michigan Online School / Rewst Platform

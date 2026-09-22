# AimPark Mobile App: Onboarding Flow Specification

**Document Purpose**: Functional and UX implementation specification for the mobile app onboarding flow. This document defines process logic, data handling, validation, interactions, and copy. **UI/design styling is excluded** — apply your own design system.

**Target Platform**: Mobile app (student/staff user registration)  
**Flow Duration**: 7 screens, avg completion time ~3–5 minutes  
**Data Persistence**: localStorage (Web) / local device storage (mobile implementation)

---

## 1. SCREEN SEQUENCE & OVERVIEW

| Screen # | Functional Name | Purpose | Primary Action | Gate |
|----------|-----------------|---------|-----------------|------|
| 1 | Welcome/Hero Screen | Brand introduction, value prop | Tap "Get Started" | None |
| 2 | Email Registration | Collect email, validate format | Enter email → "Continue" | Email validation pass |
| 3 | Password Setup | Create password, verify strength | Enter password → "Create Password" | Password strength ≥ Medium |
| 4 | OTP Verification | Verify email ownership | Enter 6-digit OTP → "Verify" | OTP matches sent code |
| 5 | Profile Information | Collect name and affiliation | Enter name, select affiliation → "Next" | Name not empty, affiliation selected |
| 6 | Vehicle Registration | Capture vehicle photos, extract details via OCR | Capture photo 1 & 2 → "Confirm Details" | Both photos captured, license plate readable |
| 7 | Success/Onboarding Complete | Celebrate completion, prompt next action | Tap "Let's Go" or "View Profile" | Completes flow |

---

## 2. DATA STRUCTURE & PERSISTENCE

### 2.1 Form Data Object
All data is collected and stored locally. Structure:

```
{
  email: string,           // Format: valid email (regex: /^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  password: string,        // Min 8 chars, at least 1 uppercase, 1 number, 1 special char
  passwordStrength: string, // "weak" | "medium" | "strong"
  name: string,            // First name + Last name
  affiliation: string,     // "student" | "faculty" | "employee" | "visitor"
  vehicle: {
    licensePlate: string,  // Extracted from OCR
    make: string,          // Extracted from OCR (or manual input fallback)
    model: string,         // Extracted from OCR (or manual input fallback)
    color: string,         // Extracted from OCR (or manual input fallback)
    photoUri1: string,     // Path/URI to first captured photo (front view)
    photoUri2: string,     // Path/URI to second captured photo (side view)
    ocrConfidence: number  // 0–100, confidence score from OCR engine
  },
  otp: {
    sentCode: string,      // 6-digit code sent to email (backend only)
    enteredCode: string,   // User-entered OTP
    expiresAt: timestamp,  // OTP expiration time (backend validation)
    attempts: number       // Track failed attempts (optional)
  },
  registrationCompleted: boolean, // True when flow reaches screen 7
  createdAt: timestamp     // Registration start time
}
```

### 2.2 Persistence Strategy
- **Save Point**: After each screen transition (auto-save on "Continue" / "Next" button)
- **Save Trigger**: Before navigation to next screen, validate all current screen fields first
- **Recovery**: On app launch, check if partial registration exists → resume at last saved screen
- **Clear**: On successful completion (screen 7), move data to persistent user profile; optionally clear temp registration data

---

## 3. SCREEN-BY-SCREEN SPECIFICATION

---

### SCREEN 1: WELCOME/HERO SCREEN

**Purpose**: Introduce AimPark value proposition and establish emotional connection.

**Layout Elements**:
- Hero graphic/animation placeholder (your design system)
- Brand name (AimPark)
- Headline value proposition
- 3–4 benefit statements (listed below)
- Call-to-action button
- Optional: Secondary link (e.g., "Already have account? Sign in")

**Copy/Microcopy**:
- **Headline**: "Find a Parking Spot in Seconds"
- **Subheadline**: "No more circles. No more stress."
- **Benefit 1**: "Real-time availability across campus"
- **Benefit 2**: "Reserve your spot instantly"
- **Benefit 3**: "Hassle-free payment and permits"
- **Primary CTA Button**: "Get Started"
- **Secondary CTA (optional)**: "I Already Have an Account"

**Interactions**:
- Tap "Get Started" → Navigate to Screen 2 (Email Registration)
- Tap "Already Have Account" (if included) → Navigate to login flow (out of scope)
- (Optional) Mascot appears with welcome gesture/animation

**Mascot Behavior** (if included):
- Appears on load with subtle entrance animation (opacity fade-in, 300ms duration)
- Displays friendly/welcoming pose
- Does NOT appear again until Screen 7 (success)

**Navigation Guards**:
- No back button (first screen)
- No validation required
- Always proceed to Screen 2 on "Get Started" tap

**Data Saved**: None

---

### SCREEN 2: EMAIL REGISTRATION

**Purpose**: Collect and validate user email address.

**Layout Elements**:
- Screen title: "What's Your Email?"
- Progress indicator: "Step 1 of 7"
- Email input field
- "Continue" button (enabled only when email is valid)
- Back button (returns to Screen 1)
- Optional: Info text about why email is needed

**Field Specifications**:

| Field | Type | Validation Rule | Error Message | Placeholder |
|-------|------|-----------------|----------------|-------------|
| Email | Text input, 48px height | `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` | "Please enter a valid email address" | "student@university.edu" |

**Validation Logic**:
- Trigger: On every keystroke (real-time validation)
- Valid state: Email matches regex
- Invalid state: Email is empty OR does not match regex
- Display error message BELOW input field (red text, small font) if invalid
- "Continue" button becomes enabled only when email is valid

**Microcopy**:
- **Field Label**: "Email Address"
- **Info Text** (optional): "We'll use this to verify your account and send important updates"
- **Error Message**: "Please enter a valid email address"
- **Button Label**: "Continue"

**Interactions**:
- Tap email field → keyboard opens
- Type email → real-time validation (show/hide error message, enable/disable button)
- Tap "Continue" (when valid) → Save email to form data → Navigate to Screen 3
- Tap back button → Return to Screen 1 (discard Screen 2 data)

**State Indicators**:
- Invalid state: Error message visible, button disabled
- Valid state: Error hidden, button enabled
- Loading state: Not applicable for this screen

**Navigation Guards**:
- Cannot proceed to Screen 3 unless email is valid
- Back button returns to Screen 1

**Data Saved**: `formData.email = <entered email>`

---

### SCREEN 3: PASSWORD SETUP

**Purpose**: Create and verify password strength.

**Layout Elements**:
- Screen title: "Create a Strong Password"
- Progress indicator: "Step 2 of 7"
- Password input field (masked)
- Password strength indicator (3-tier visual + descriptive text)
- Confirm password input field (masked)
- "Create Password" button (enabled only when both fields valid and strengths match)
- Back button

**Field Specifications**:

| Field | Type | Validation Rule | Placeholder |
|-------|------|-----------------|-------------|
| Password | Masked text input, 48px height | Min 8 chars, 1 uppercase, 1 number, 1 special char | "Minimum 8 characters" |
| Confirm Password | Masked text input, 48px height | Must match password field | "Re-enter password" |

**Password Strength Algorithm**:
- **Weak** (red): 8–10 characters, missing requirements (e.g., no number or special char)
- **Medium** (yellow/orange): 10–15 characters, has 3 of 4 requirements (uppercase, number, special char, length)
- **Strong** (green): 15+ characters OR has all 4 requirements met

**Strength Indicator Display**:
- Show 3 bars (left to right): [Bar 1] [Bar 2] [Bar 3]
- Weak: 1 bar filled (red)
- Medium: 2 bars filled (orange/yellow)
- Strong: 3 bars filled (green)
- Below bars: Descriptive text ("Weak", "Medium", "Strong")
- Optional: Additional hint text (e.g., "Add a special character" for Weak state)

**Validation Logic**:
- Trigger: On every keystroke in password field
- Update strength indicator in real-time
- Check confirm password only after user types in confirm field
- Show error if passwords don't match
- "Create Password" button enabled only when:
  - Password field has strength ≥ Medium
  - Confirm password matches password field
  - Both fields not empty

**Microcopy**:
- **Field Label 1**: "Password"
- **Field Label 2**: "Confirm Password"
- **Strength Text** (dynamic):
  - Weak: "Weak — Add uppercase, number, and special character"
  - Medium: "Good — Add more characters or special symbols for stronger security"
  - Strong: "Strong — This password is secure"
- **Match Error**: "Passwords don't match. Try again."
- **Button Label**: "Create Password"

**Interactions**:
- Tap password field → Keyboard opens
- Type password → Strength indicator updates in real-time
- Tap confirm password field → Keyboard opens
- Type confirm password → Validation checks match
- Tap "Create Password" (when valid) → Save password data → Navigate to Screen 4
- Tap back button → Return to Screen 2 (retain email, discard password)

**State Indicators**:
- Weak strength: Bars red, text "Weak"
- Medium strength: Bars orange, text "Good", button disabled
- Strong strength: Bars green, text "Strong", button enabled
- Password mismatch: Error message visible, button disabled

**Navigation Guards**:
- Cannot proceed to Screen 4 unless password strength ≥ Medium AND passwords match
- Back button returns to Screen 2

**Data Saved**:
```
formData.password = <entered password>
formData.passwordStrength = "weak" | "medium" | "strong"
```

---

### SCREEN 4: OTP VERIFICATION

**Purpose**: Verify email ownership via one-time password.

**Layout Elements**:
- Screen title: "Verify Your Email"
- Progress indicator: "Step 3 of 7"
- Info text: "We sent a 6-digit code to [email from Screen 2]"
- OTP input field (6 boxes for 6 digits, or single masked field)
- Countdown timer (45 seconds)
- "Verify" button (enabled only when 6 digits entered)
- "Resend Code" button (disabled until timer expires OR manual resend)
- Back button

**OTP Specifications**:
- **Length**: 6 digits (0–9 only)
- **Validity Duration**: 45 seconds from send
- **Backend Validation**: Compare enteredCode with sentCode
- **Max Attempts**: Optional — track if you want to limit retries (e.g., 3 attempts before resend required)

**Timer Behavior**:
- Start: 45 seconds on screen load
- Display format: "Code expires in: 0:45" (decrements every second)
- Reaching 0:00: "Code expired. Request a new one."
- Timer stops at 0, does not go negative

**Validation Logic**:
- Trigger: On every digit entered
- Valid state: Exactly 6 numeric digits entered
- "Verify" button enabled only when 6 digits present
- On tap "Verify": Validate against backend sentCode
  - If match: Proceed to Screen 5
  - If no match: Show error "Incorrect code. Try again." → Retain entered digits, allow re-entry

**Resend Logic**:
- Resend button disabled while timer active (> 0:00)
- Resend button enabled when timer reaches 0:00
- Tap "Resend Code": 
  - Reset timer to 45 seconds
  - Request new OTP from backend
  - Clear previous OTP input field
  - Show confirmation message: "Code sent to [email]"

**Microcopy**:
- **Title**: "Verify Your Email"
- **Info Text**: "We sent a 6-digit code to [email]. It expires in 45 seconds."
- **Field Label**: "Enter Code"
- **Placeholder** (if single field): "000000"
- **Countdown Display**: "Code expires in: 0:MM:SS"
- **Expired Message**: "Code expired. Tap 'Resend Code' to get a new one."
- **Error Message** (incorrect): "Incorrect code. Try again."
- **Success Message** (auto on verification): None (auto-navigate to Screen 5)
- **Button Label (Verify)**: "Verify"
- **Button Label (Resend)**: "Resend Code" (disabled/grayed out while timer active)

**Interactions**:
- Tap OTP input field → Keyboard opens (numeric only)
- Type 6 digits → "Verify" button becomes enabled
- Tap "Verify" (when 6 digits present) → Validate against backend → On success, navigate to Screen 5
- Tap "Resend Code" (only available after timer expires) → Reset timer, resend OTP, clear field
- Tap back button → Return to Screen 3 (retain email & password, discard OTP attempt)
- Timer counts down every second

**State Indicators**:
- Loading state (on "Verify" tap): Show spinner animation (300–500ms) with text "Verifying code..."
- Error state: Error message visible, input field highlighted (red border optional), "Verify" button re-enabled for retry
- Success state: Auto-navigate (no user action needed after validation passes)

**Navigation Guards**:
- Cannot proceed to Screen 5 unless OTP is valid
- If user taps back, OTP state is cleared but email/password retained
- Timer resets on screen load

**Data Saved**:
```
formData.otp.enteredCode = <entered OTP>
formData.otp.expiresAt = <timestamp 45 seconds from OTP send>
```

---

### SCREEN 5: PROFILE INFORMATION

**Purpose**: Collect user name and affiliation (student, faculty, employee, visitor).

**Layout Elements**:
- Screen title: "Tell Us About Yourself"
- Progress indicator: "Step 4 of 7"
- Name input field (first + last name, single field or two separate fields)
- Affiliation selector (radio buttons, dropdown, or segmented control)
- Affiliation benefit preview button (optional, links to modal)
- "Next" button (enabled only when name & affiliation selected)
- Back button

**Field Specifications**:

| Field | Type | Validation Rule | Placeholder |
|-------|------|-----------------|-------------|
| Name | Text input, 48px height | Not empty, min 2 characters | "First and last name" |
| Affiliation | Selection (radio/dropdown/segmented) | One option selected from 4 | N/A |

**Affiliation Options** (hardcoded, no conditional):
1. **Student**
   - Description: "Access free parking at Gate 1"
   - Badge/Label: "Free"
2. **Faculty**
   - Description: "Reserved premium spots on campus"
   - Badge/Label: "Premium"
3. **Employee**
   - Description: "Monthly permit with flexible arrival times"
   - Badge/Label: "Monthly"
4. **Visitor**
   - Description: "Daily rates and hourly options"
   - Badge/Label: "Hourly"

**Validation Logic**:
- Trigger: On keystroke (name), on selection (affiliation)
- Name valid: Not empty AND min 2 characters
- Affiliation valid: One option selected (default is none)
- "Next" button enabled only when BOTH name AND affiliation are selected/valid

**Affiliation Benefit Preview Modal** (optional, triggered by optional button):
- Trigger: Tap "See Benefits" or "Compare Plans" button
- Modal displays all 4 affiliations side-by-side:
  - Affiliation name
  - Description
  - Key benefits (2–3 bullet points)
  - Badge/label
- Modal close: Tap "Got It", tap outside modal, or back button
- Returning to main screen: Selected affiliation (if any) is retained

**Microcopy**:
- **Title**: "Tell Us About Yourself"
- **Field Label**: "Full Name"
- **Affiliation Label**: "What's Your Affiliation?"
- **Preview Button** (optional): "See Benefits" or "Compare Plans"
- **Button Label**: "Next"
- **Affiliation Descriptions** (as listed above under "Affiliation Options")

**Interactions**:
- Tap name field → Keyboard opens
- Type name → Validation shows real-time feedback (if empty, subtle hint text appears)
- Tap affiliation option → Selection toggles, option highlighted
- Tap "See Benefits" (optional) → Affiliation preview modal opens (see Modal Spec below)
- Tap "Next" (when name & affiliation valid) → Save profile data → Navigate to Screen 6
- Tap back button → Return to Screen 4 (retain email, password, OTP; discard name & affiliation)

**State Indicators**:
- Name empty: "Next" button disabled
- Affiliation not selected: "Next" button disabled
- Both valid: "Next" button enabled
- Selection highlight: Affiliation option has visual focus state (border, background color, checkmark — per your design system)

**Navigation Guards**:
- Cannot proceed to Screen 6 unless name is not empty AND affiliation is selected
- Back button returns to Screen 4

**Data Saved**:
```
formData.name = <entered name>
formData.affiliation = "student" | "faculty" | "employee" | "visitor"
```

---

#### AFFILIATION BENEFIT PREVIEW MODAL (Screen 5 Expansion)

**Trigger**: Tap "See Benefits" / "Compare Plans" button on Screen 5

**Modal Structure**:
- **Title**: "Affiliation Benefits"
- **Close Action**: Tap X button, tap outside modal, or "Got It" button
- **Layout**: Horizontal scroll OR vertical stack (all 4 visible)
- **Card per affiliation**:
  - Affiliation name (bold)
  - Badge/label (e.g., "Free", "Premium")
  - Description (1–2 lines)
  - Benefits list (2–3 bullet points):
    - **Student**: "Free parking at Gate 1", "Peak hours 7am–6pm"
    - **Faculty**: "Reserved premium spots", "Discounted monthly rates", "Priority access"
    - **Employee**: "Monthly permit ($50/month)", "Flexible arrival times", "24/7 access"
    - **Visitor**: "Daily rates ($5–10)", "Hourly options ($2/hr)", "One-time registration"

**Modal Behavior**:
- Modal overlay (semi-transparent background, blocks interaction with page behind)
- Modal content centered (or bottom sheet, per your design system)
- Does not close on selection (user must explicitly close)
- Returning to Screen 5: User's previous affiliation selection (if any) is retained

---

### SCREEN 6: VEHICLE REGISTRATION

**Purpose**: Capture vehicle photos and extract vehicle details via OCR.

**Layout Elements**:
- Screen title: "Register Your Vehicle"
- Progress indicator: "Step 5 of 7"
- "Photo 1 of 2" or "Front View" label
- Photo capture frame / preview placeholder
- "Take Photo" button (camera icon)
- Loading state (spinner + "Processing photo...") appears during OCR
- OCR feedback text (e.g., "License plate detected: XYZ-1234" OR "Couldn't read plate. Try again.")
- Auto-populated fields (extracted from OCR):
  - License Plate (auto-filled, editable)
  - Make (auto-filled, editable)
  - Model (auto-filled, editable)
  - Color (auto-filled, editable)
- Confirmation prompt: After Photo 2 captured, show extracted vehicle details for confirmation
- "Confirm Details" button (enabled after both photos captured)
- Back button

**Photo Capture Specifications**:
- **Photo 1**: Front view (license plate clearly visible)
- **Photo 2**: Side view (vehicle side/profile, license plate visible)
- **Timing**: Show loading state for ~800ms after photo capture (simulate OCR processing)
- **Feedback**: After loading, show OCR result (success or error)

**OCR Extraction & Fallback**:
- **Ideal outcome**: OCR successfully extracts:
  - License plate (alphanumeric string)
  - Make (e.g., "Toyota")
  - Model (e.g., "Corolla")
  - Color (e.g., "Blue")
  - Confidence score (0–100)
- **Fallback outcome** (confidence < threshold OR OCR fails):
  - Show error: "Couldn't read license plate clearly. Please try again or enter manually."
  - Display manual entry fields for all vehicle details
  - User can manually type values

**Field Specifications** (Post-OCR, editable):

| Field | Type | Validation Rule | Editable | Placeholder |
|-------|------|-----------------|----------|-------------|
| License Plate | Text, 48px height | Not empty, alphanumeric | Yes | "ABC-1234" |
| Make | Text, 48px height | Not empty | Yes | "Toyota" |
| Model | Text, 48px height | Not empty | Yes | "Corolla" |
| Color | Text or color picker, 48px height | Not empty | Yes | "Blue" |

**Validation Logic**:
- Photo 1 captured: Show feedback (success or error)
- Photo 2 captured: Repeat feedback
- Extracted fields auto-populated from OCR (or show manual entry form if OCR failed)
- All fields must be non-empty to enable "Confirm Details" button
- User can edit any field (overrides OCR extraction if needed)

**Microcopy**:
- **Photo 1 Label**: "Photo 1 of 2 — Front View"
- **Photo 2 Label**: "Photo 2 of 2 — Side View"
- **Photo Instruction**: "Make sure license plate is clearly visible"
- **Button Label**: "Take Photo"
- **Loading Text**: "Processing photo..."
- **OCR Success**: "License plate detected: [XYZ-1234]"
- **OCR Error**: "Couldn't read license plate. Please try again or enter details below."
- **Confirmation Heading** (after Photo 2): "Is this your vehicle?"
- **Field Labels**: "License Plate", "Make", "Model", "Color"
- **Button Label (Confirm)**: "Confirm Details"
- **Hint Text** (optional): "You can edit any details if needed"

**Interactions**:
- Tap "Take Photo" → Camera opens
- Take photo → Camera closes
- Loading state appears (800ms) → OCR processing
- Feedback displays (success or error)
- If OCR success: Fields auto-populated → User can tap to edit
- If OCR fails: Manual entry form shown → User types details
- After Photo 1 captured: UI updates to "Photo 2 of 2"
- After Photo 2 captured: Confirmation screen displays all extracted details
- Tap "Confirm Details" (when all fields filled) → Save vehicle data → Navigate to Screen 7
- Tap back button → Return to Screen 5 (retain name & affiliation; discard vehicle photos & details)

**State Indicators**:
- Photo 1 not captured: "Take Photo" button active, Photo 2 section hidden
- Photo 1 captured: Photo preview displays, OCR feedback visible, Photo 2 section appears
- OCR processing: Spinner animation + "Processing photo..." text
- OCR success: Fields auto-populated (editable)
- OCR failure: Manual entry form displayed, error message visible
- Photo 2 captured: Confirmation screen with all vehicle details
- All details valid: "Confirm Details" button enabled

**Mascot Behavior** (optional):
- After Photo 1 capture: Mascot appears with encouragement gesture/pose (e.g., thumbs up, smile)
- After Photo 2 capture: Mascot appears with celebration pose (ready for next stage)
- Mascot persists until navigation away OR dismissed by user

**Navigation Guards**:
- Cannot proceed to Screen 7 unless both photos captured AND all vehicle details fields filled
- Back button returns to Screen 5

**Data Saved**:
```
formData.vehicle = {
  licensePlate: <extracted or manually entered>,
  make: <extracted or manually entered>,
  model: <extracted or manually entered>,
  color: <extracted or manually entered>,
  photoUri1: <path to Photo 1>,
  photoUri2: <path to Photo 2>,
  ocrConfidence: <0–100 score from OCR engine>
}
```

---

### SCREEN 7: SUCCESS / ONBOARDING COMPLETE

**Purpose**: Celebrate registration completion and prompt next action.

**Layout Elements**:
- Success graphic/animation (e.g., checkmark, confetti) — placeholder for your design
- Screen title: "All Set!"
- Subheading: Success message
- Summary of key info (user name, email, affiliation, vehicle)
- Congratulations message with mascot (optional)
- Primary CTA: "Let's Go" or "Start Parking"
- Secondary CTA: "View Profile" (optional)
- No back button (flow complete)

**Progress Indicator**: "Step 7 of 7" (final step)

**Summary Display** (read-only):
- **User Name**: [name from Screen 5]
- **Email**: [email from Screen 2]
- **Affiliation**: [affiliation label from Screen 5]
- **Vehicle**: [license plate from Screen 6]

**Microcopy**:
- **Title**: "All Set!"
- **Subtitle**: "Your AimPark account is ready to go."
- **Congratulations Text**: "Welcome to AimPark, [user name]! You're all set to find parking instantly."
- **Summary Header** (optional): "Here's what we have on file:"
- **Primary Button**: "Let's Go" or "Start Parking"
- **Secondary Button** (optional): "View Profile"

**Interactions**:
- Tap "Let's Go" → Exit onboarding, navigate to main parking search flow / home screen
- Tap "View Profile" (optional) → Navigate to user profile screen (out of scope)
- Mascot displays celebration animation (if included)
- No back button available

**State Indicators**:
- Success checkmark / confetti animation on load
- Mascot celebration pose displayed

**Mascot Behavior** (if included):
- Mascot appears with celebration animation (e.g., dance, confetti release)
- Accompanied by success sound/haptic feedback (optional)
- Persists on screen until user taps CTA

**Navigation Guards**:
- No back button
- Flow is complete
- Data is persisted to main user profile

**Data Saved / Finalized**:
```
User registration marked complete
formData.registrationCompleted = true
Data moved to permanent user profile
Temp registration data cleared (optional)
```

---

## 4. INTERACTIVE STATES & TRANSITIONS

### 4.1 Loading States

All async operations (OTP verification, OCR processing, network calls) display a loading indicator:

| Operation | Trigger | Duration | Display | Text |
|-----------|---------|----------|---------|------|
| Email validation | Keystroke | Instant | Inline error/success | See Screen 2 |
| Password strength check | Keystroke | Instant | Strength bars + text | See Screen 3 |
| OTP verification | "Verify" tap | 300–500ms | Centered spinner overlay | "Verifying code..." |
| Photo OCR processing | Photo capture | ~800ms | Spinner + fade overlay | "Processing photo..." |
| Form submission | "Confirm Details" tap | 300–500ms | Spinner overlay | "Saving your details..." |

**Loading Animation Specs**:
- Spinner: Rotating icon (your design system)
- Duration: As specified above
- Overlay: Semi-transparent background (if full screen)
- User cannot interact with other elements during loading

### 4.2 Error States

| Screen | Error Type | Display | Recovery |
|--------|-----------|---------|----------|
| Screen 2 | Invalid email format | Red text below field | Clear field, allow re-entry |
| Screen 3 | Weak password | Strength bars update, button disabled | Add characters / special chars |
| Screen 3 | Password mismatch | Red error text | Correct confirm field |
| Screen 4 | Incorrect OTP | Error message, input cleared OR retained | Allow up to 3 retries (optional), then require "Resend Code" |
| Screen 4 | OTP expired | "Code expired" message | Tap "Resend Code" |
| Screen 5 | Name empty | Field remains focused or hint text | User enters name |
| Screen 6 | Photo OCR failed | "Couldn't read plate" message | Manual entry fields OR retake photo |
| Screen 6 | Missing vehicle details | "Confirm Details" button disabled | Fill all fields |

**Error Display Conventions**:
- Error text: Red color (per your design system)
- Placement: Below or inside the field
- Font size: Smaller than field label
- Cleared: When user corrects the issue OR when navigating away

### 4.3 Disabled States

| Element | Condition | Appearance | Interaction |
|---------|-----------|------------|-------------|
| "Continue" (Screen 2) | Email invalid or empty | Grayed out, reduced opacity | No tap response |
| "Create Password" (Screen 3) | Password strength < Medium OR passwords don't match | Grayed out, reduced opacity | No tap response |
| "Verify" (Screen 4) | OTP < 6 digits | Grayed out, reduced opacity | No tap response |
| "Resend Code" (Screen 4) | Timer > 0:00 | Grayed out, reduced opacity | No tap response |
| "Next" (Screen 5) | Name empty OR affiliation not selected | Grayed out, reduced opacity | No tap response |
| "Confirm Details" (Screen 6) | Photos not captured OR vehicle fields incomplete | Grayed out, reduced opacity | No tap response |

---

## 5. FORM DATA FLOW & PERSISTENCE

### 5.1 Save Points
| Screen | Save Trigger | Data Saved | Timing |
|--------|--------------|-----------|--------|
| 1 | "Get Started" tap | None | N/A |
| 2 | "Continue" tap (email valid) | email | Before Screen 3 navigation |
| 3 | "Create Password" tap (password valid) | password, passwordStrength | Before Screen 4 navigation |
| 4 | "Verify" tap (OTP valid) | otp.enteredCode | After verification success |
| 5 | "Next" tap (name & affiliation valid) | name, affiliation | Before Screen 6 navigation |
| 6 | "Confirm Details" tap (all fields filled) | vehicle details, photoUri | Before Screen 7 navigation |
| 7 | Auto on load | registrationCompleted = true | After Screen 7 displays |

### 5.2 Recovery Flow
If user closes app / loses session mid-registration:

1. **On app re-launch**: Check localStorage for `registrationData`
2. **If data exists**: 
   - Determine last completed screen
   - Resume at next incomplete screen (e.g., if email saved but no password, resume Screen 3)
   - Pre-populate saved fields
   - Show resumption message (optional): "Welcome back! Continuing your registration..."
3. **If data does not exist**: Start fresh at Screen 1
4. **On successful completion** (Screen 7): Archive data to user profile, clear temp registration data

### 5.3 Data Expiry
- **Registration session timeout**: Optional — expire incomplete registration after 1 hour of inactivity
- **OTP code timeout**: Expires after 45 seconds (enforced on Screen 4)
- **No timeout for**: Email, password, name, affiliation, vehicle details (persist until user explicitly completes or clears)

---

## 6. NAVIGATION FLOW & GUARDRAILS

### 6.1 Forward Navigation
```
Screen 1 → Screen 2 (on "Get Started")
Screen 2 → Screen 3 (on "Continue", email valid)
Screen 3 → Screen 4 (on "Create Password", strength ≥ Medium)
Screen 4 → Screen 5 (on "Verify", OTP valid)
Screen 5 → Screen 6 (on "Next", name filled & affiliation selected)
Screen 6 → Screen 7 (on "Confirm Details", all vehicle fields filled)
Screen 7 → Main app (on "Let's Go" or "Start Parking")
```

### 6.2 Back Navigation
```
Screen 2 → Screen 1 (back button)
Screen 3 → Screen 2 (back button, retain email)
Screen 4 → Screen 3 (back button, retain email & password)
Screen 5 → Screen 4 (back button, retain email, password & OTP)
Screen 6 → Screen 5 (back button, retain email, password, OTP, name & affiliation)
Screen 7 → NO BACK (flow complete)
```

### 6.3 Data Retention on Back
- **Screen 2 ← Screen 3**: Email retained, password discarded
- **Screen 3 ← Screen 4**: Email & password retained, OTP discarded
- **Screen 4 ← Screen 5**: Email, password & OTP retained, name & affiliation discarded
- **Screen 5 ← Screen 6**: Email, password, OTP, name & affiliation retained, vehicle details discarded
- **Screen 1 ← Screen 2**: All data discarded (start fresh)

### 6.4 Boundary Conditions
- **Cannot skip steps**: Validation gates prevent forward progression
- **Cannot access screens out of order**: No direct navigation links to future screens
- **Cannot return past Screen 1**: Screen 1 has no back button
- **Cannot return from Screen 7**: Screen 7 is completion point; back button not present

---

## 7. AFFILIATION FEATURE EXPANSION (CORE FLOW)

### 7.1 Feature Card Expansion Modal (Screen 5 Expansion)

Triggered by optional "See Benefits" button on Screen 5. This is NOT a separate screen but an overlay modal.

**Modal Structure**:
- Displays all 4 affiliations in expandable/scrollable cards
- Each card shows:
  - Affiliation name
  - Badge label (Free, Premium, Monthly, Hourly)
  - Key description (1–2 lines)
  - Benefits list (2–3 bullets)

**Cards**:

**1. Student**
- Label: "Student"
- Badge: "Free"
- Description: "Access free parking at Gate 1 during peak hours"
- Benefits:
  - Free parking at Gate 1 (7am–6pm)
  - Priority availability info
  - Campus event parking

**2. Faculty**
- Label: "Faculty"
- Badge: "Premium"
- Description: "Reserved premium spots on campus with priority access"
- Benefits:
  - Reserved premium spots
  - Discounted monthly rates ($20/month optional)
  - 24/7 campus access

**3. Employee**
- Label: "Employee"
- Badge: "Monthly"
- Description: "Monthly permit with flexible arrival times"
- Benefits:
  - Monthly permit ($50/month)
  - Flexible arrival times
  - 24/7 access

**4. Visitor**
- Label: "Visitor"
- Badge: "Hourly"
- Description: "Daily rates and hourly parking options"
- Benefits:
  - Daily rates ($5–10)
  - Hourly rates ($2/hour)
  - No long-term commitment

**Modal Behavior**:
- Tap outside modal to close
- Tap X button to close
- Tap "Got It" or "Done" to close
- Does NOT auto-close on affiliation selection
- Returns to Screen 5 with user's previous selection (if any) intact

---

## 8. FEATURE CARD EXPANSION MODAL (Optional, Feature Discovery)

**Note**: This is separate from the affiliation preview and appears during onboarding (not specified in current screen flow but may be added to Screen 1 or as a toggleable element on any screen).

**Trigger**: Tap on feature highlight cards (if included on Screen 1)

**Features Documented**:
1. **Find a Spot Instantly**
   - Icon: Placeholder
   - Description: "Real-time availability across all campus parking zones"
   - Use Case: "No more circling. Know where spaces are before you leave"

2. **No Coins, No Hassle**
   - Icon: Placeholder
   - Description: "Digital payment integrated with student/employee accounts"
   - Use Case: "Pay via app, no loose change needed"

3. **Prove It Wasn't Your Fault**
   - Icon: Placeholder
   - Description: "Photo evidence system for disputes"
   - Use Case: "Dispute a ticket with timestamped photos of your spot"

4. **We Remember for You**
   - Icon: Placeholder
   - Description: "Saved favorite spots and frequently used parking zones"
   - Use Case: "Quick access to your go-to parking areas"

5. **Report Damage or Blockage**
   - Icon: Placeholder
   - Description: "Community flagging system for maintenance issues"
   - Use Case: "Alert admin to broken sensors or blocked spots"

**Modal Display**:
- Feature name (bold)
- Icon (placeholder for your design system)
- Full description (1–2 sentences)
- Use case / benefit (italicized or muted text)
- Modal close: Tap X, tap outside, or "Got It"

---

## 9. MASCOT BEHAVIOR & REACTIONS

**Mascot Appearances** (if mascot feature included):

| Screen | Trigger | Pose/Animation | Duration | Interaction |
|--------|---------|----------------|----------|-------------|
| 1 | Load | Entrance fade-in + welcome gesture | 500ms entrance, stays | Optional dismissal |
| 5 | Load | Subtle wave or friendly stance | Stays visible | Dismissible |
| 6 (Photo 1) | Photo captured | Encouragement pose (thumbs up, smile) | 1–2s display | Auto-dismiss or tap to continue |
| 6 (Photo 2) | Photo captured | Celebration pose (ready for next stage) | 1–2s display | Auto-dismiss or tap to continue |
| 7 | Load | Celebration animation (dance, confetti) | 2–3s loop | Persists until CTA tap |

**Animation Specs**:
- **Entrance (Screen 1)**: Opacity 0 → 1 over 300–500ms
- **Encouragement (Screen 6 Photo 1)**: Fade in, hold pose, fade out or stay
- **Celebration (Screen 7)**: Scale up slightly, possible confetti/particle effect, loop animation

**Dismissal**:
- Tap mascot to dismiss (optional)
- Auto-dismiss after set duration OR on user action (CTA tap)
- Does not block user interaction with form

---

## 10. COPY & MICROCOPY GUIDELINES

### 10.1 Tone & Voice
- **Friendly**: Avoid corporate jargon
- **Clear & Concise**: Short sentences, simple words
- **Encouraging**: Use positive framing ("You're almost there!" vs. "Don't forget")
- **Contextual**: Reference previous user inputs (e.g., "Welcome back, [name]!")

### 10.2 Field Labels
- Descriptive but not verbose (1–3 words)
- Examples: "Email Address", "Password", "Full Name", "Affiliation"

### 10.3 Error Messages
- Explain what went wrong (not just "Error")
- Suggest how to fix it (e.g., "Please enter a valid email address" vs. "Invalid")
- Use red color for visibility

### 10.4 Success Messages
- Confirm completion (e.g., "Code verified successfully")
- Motivational tone (e.g., "Great! You're one step closer")
- May auto-navigate (no explicit "OK" button required)

### 10.5 Button Labels
- **Action-oriented**: Use verbs ("Continue", "Verify", "Confirm Details", not "OK" or "Next")
- **Specific to context**: "Resend Code" vs. generic "Resend"
- **Progressive language**: Match the user's mental model

### 10.6 Hint & Info Text
- Optional but recommended
- Placed below field labels or above input
- Smaller font, muted color
- Examples:
  - "We'll use this to verify your account and send updates"
  - "Minimum 8 characters, 1 uppercase letter, 1 number"
  - "Make sure license plate is clearly visible"

---

## 11. VALIDATION SUMMARY TABLE

| Screen | Field | Validation Rule | Feedback | Gate |
|--------|-------|-----------------|----------|------|
| 2 | Email | `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` | "Please enter a valid email address" | Yes (cannot proceed) |
| 3 | Password | 8+ chars, 1 uppercase, 1 number, 1 special char | Strength bars + descriptive text | Yes (strength ≥ Medium) |
| 3 | Confirm Password | Must match password field | "Passwords don't match. Try again." | Yes (must match) |
| 4 | OTP | Exactly 6 numeric digits | Inline validation (enable/disable button) | Yes (6 digits required) |
| 4 | OTP | Match backend sentCode | "Incorrect code. Try again." | Yes (backend validation) |
| 4 | OTP | Not expired (< 45 seconds) | "Code expired. Resend Code." | Yes (timer check) |
| 5 | Name | Not empty, min 2 characters | Inline validation | Yes (name required) |
| 5 | Affiliation | One option selected | Visual selection indicator | Yes (affiliation required) |
| 6 | License Plate | Not empty, alphanumeric | Inline validation | Yes (required) |
| 6 | Make | Not empty | Inline validation | Yes (required) |
| 6 | Model | Not empty | Inline validation | Yes (required) |
| 6 | Color | Not empty | Inline validation | Yes (required) |
| 6 | Photos | Both captured, readable license plate | OCR feedback | Yes (both required) |

---

## 12. TECHNICAL IMPLEMENTATION NOTES

### 12.1 Storage Layer
- Use native mobile storage (iOS: UserDefaults or Keychain; Android: SharedPreferences or EncryptedSharedPreferences)
- Or use Web-based localStorage if app is web-based (with HTTPS encryption)
- Store sensitive data (password) securely; consider hashing locally before transmission

### 12.2 Validation Layer
- Client-side: Real-time feedback (email regex, password strength)
- Server-side: Email verification, OTP validation, duplicate registration check
- OTP code: Generated server-side, sent via email, never stored on client

### 12.3 Photo & OCR Layer
- Integrate OCR library (e.g., Firebase ML Kit, AWS Textract, Tesseract.js)
- Compress photos before upload (e.g., 70–80% quality)
- Fallback: Manual entry form if OCR fails or confidence score < threshold
- Photo storage: Upload to backend after Screen 6 confirmation, or store locally with temp URI

### 12.4 Navigation & State Management
- Use stack-based navigation (push/pop) for back button behavior
- Maintain form state in memory during session
- Persist form state to storage before navigation between major sections
- Clear form state after successful registration completion

### 12.5 Localization (Future)
- All microcopy strings should be externalizable for translation
- Account for text expansion in other languages (German, Spanish, etc.)

---

## 13. TESTING CHECKLIST (Functional Verification)

### Screen 1
- [ ] "Get Started" navigates to Screen 2
- [ ] (Optional) "Already Have Account" navigates to login flow

### Screen 2
- [ ] Invalid email shows error message
- [ ] Valid email enables "Continue" button
- [ ] "Continue" saves email and navigates to Screen 3
- [ ] Back button returns to Screen 1

### Screen 3
- [ ] Password strength updates in real-time
- [ ] Weak password disables button
- [ ] Medium/Strong password enables button (if passwords match)
- [ ] Mismatched passwords show error
- [ ] "Create Password" saves password and navigates to Screen 4
- [ ] Back button returns to Screen 2, retains email

### Screen 4
- [ ] OTP input accepts 6 digits only
- [ ] Timer counts down from 45 seconds
- [ ] Incorrect OTP shows error
- [ ] Correct OTP navigates to Screen 5
- [ ] "Resend Code" disabled until timer expires
- [ ] Resend Code resets timer and clears input
- [ ] Back button returns to Screen 3, retains email & password

### Screen 5
- [ ] Name input validation works
- [ ] Affiliation selection highlights chosen option
- [ ] (Optional) "See Benefits" opens modal with all 4 affiliations
- [ ] Modal displays benefit details correctly
- [ ] Modal close returns to Screen 5, retains selection
- [ ] "Next" (when valid) saves data and navigates to Screen 6
- [ ] Back button returns to Screen 4, retains email, password & OTP

### Screen 6
- [ ] "Take Photo" opens camera
- [ ] Photo capture triggers loading state (800ms)
- [ ] OCR feedback displays correctly (success or error)
- [ ] Manual entry form appears if OCR fails
- [ ] All 4 vehicle fields must be filled before "Confirm Details" enabled
- [ ] Photo 1 captured shows "Photo 2 of 2"
- [ ] (Optional) Mascot encouragement pose after each photo
- [ ] "Confirm Details" saves vehicle data and navigates to Screen 7
- [ ] Back button returns to Screen 5, retains all previous data except vehicle

### Screen 7
- [ ] Screen 7 displays user name, email, affiliation, vehicle
- [ ] "Let's Go" exits onboarding and navigates to main app
- [ ] (Optional) Mascot celebration animation displays
- [ ] No back button present

### Cross-Screen
- [ ] Form data persists across screen navigation
- [ ] Back button always retains appropriate data
- [ ] Progress indicator displays correctly on each screen
- [ ] Loading states display on all async operations
- [ ] All error messages are clear and actionable

---

## 14. GLOSSARY & DEFINITIONS

| Term | Definition |
|------|-----------|
| **Affiliation** | User category: Student, Faculty, Employee, or Visitor |
| **Gate** | Validation checkpoint that must pass before proceeding to next screen |
| **License Plate** | Vehicle registration identifier extracted from OCR or entered manually |
| **Mascot** | Optional character/icon that appears for encouragement and celebration |
| **Modal** | Overlay dialog that appears on top of current screen (non-navigational) |
| **Microcopy** | Small text labels, hints, error messages, button labels |
| **OCR** | Optical Character Recognition — extracts text from photos |
| **OTP** | One-Time Password — 6-digit code sent to email for verification |
| **Persistence** | Saving form data to device storage for recovery if session interrupted |
| **Recovery Flow** | Process of resuming registration from last completed step after app closure |
| **State** | Current status of a form field or interactive element (valid, invalid, loading, disabled) |

---

## 15. SCREEN ACCESSIBILITY NOTES (Future)

- **Screen Reader Support**: All buttons, form fields, and interactive elements have descriptive labels
- **Touch Target Size**: All buttons and tap targets minimum 48px height (mobile standard)
- **Color Contrast**: All text meets WCAG AA standards (4.5:1 ratio for normal text)
- **Focus Order**: Tab order follows logical flow (top to bottom, left to right)
- **Alt Text**: Icons and images have descriptive alt text
- **Error Recovery**: Errors are announced to screen readers and associated with fields

---

## APPENDIX: DESIGN SYSTEM INTEGRATION POINTS

When implementing this spec with your design system, map the following:

1. **Colors**: All error/success/warning states → use your color tokens
2. **Typography**: Button labels, field labels, microcopy → use your type scale
3. **Spacing**: Field heights (48px specified), padding, margins → use your spacing scale
4. **Components**: Button, TextField, Card, Modal → use your component library
5. **Icons**: Placeholder descriptions (e.g., "success checkmark", "camera icon") → use your icon set
6. **Animations**: Loading spinners, transitions, celebrations → use your motion system
7. **Shadows & Borders**: Modal overlays, focus states → use your elevation/border tokens

---

**End of Specification**

---

**Questions During Implementation?**

If anything in this spec is unclear or needs expansion, specific sections can be elaborated with exact code examples, state diagrams, or data flow diagrams. This document is your blueprint; your design system applies the visual language.

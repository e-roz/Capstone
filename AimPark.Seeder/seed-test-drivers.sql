-- ============================================================================
--  AimPark — three ready-made driver accounts for testing without documents
-- ============================================================================
--
--  Why this exists
--  ---------------
--  Registration is the longest path in the product: email OTP, profile, three
--  photographed documents, then an admin reading them. None of it can be walked
--  by a tester who does not personally own a RAF, a driver's licence and an LTO
--  receipt — and the screens that most need eyes on them all sit *after*
--  approval, which makes them the hardest to reach.
--
--  These rows are written in the exact state a real account reaches the moment
--  an admin approves it: registration completed, account active, pre-screening
--  passed, one vehicle on file, and an RFID card already assigned. The card
--  matters — a driver with no card cannot pass a gate, and half the app then
--  has nothing to show.
--
--  The three are deliberately not copies of each other. Vehicle type decides
--  which slots are offered and affiliation decides whether enrolment expires,
--  so a student on a car, a student on a motorcycle and a faculty member cover
--  three paths instead of testing one path three times.
--
--  Safe to run more than once. Every field is written back to the seed value on
--  conflict rather than the row being skipped, because someone re-running this
--  is nearly always doing it *because* a tester cannot get in.
--
--  Run in: Supabase → SQL Editor → paste → Run.
-- ============================================================================


-- ---------------------------------------------------------------------------
--  Accounts
-- ---------------------------------------------------------------------------
--  Password hashing is done by pgcrypto, which this project already has
--  installed. gen_salt('bf', 11) produces a $2a$11$ hash — the revision and
--  work factor BCrypt.Net-Next writes and verifies, so the API accepts these
--  exactly as if the user had typed the password into the sign-up screen.
--
--  Every enum column is stored as its member *name*, not an ordinal: the EF
--  model maps all of them with HasConversion<string>(). 'Active' is right,
--  1 is not.
--
--  Email is stored lowercase because IdentifierNormalizer.NormalizeEmail
--  lowercases before the login lookup — a capital letter here is an account
--  nobody can sign in to.

INSERT INTO "Users" (
    "Id", "FullName", "Email", "IsEmailVerified", "PasswordHash",
    "AuthProvider", "ExternalProviderId", "Role", "Affiliation",
    "StudentNumber", "Section", "EnrollmentValidUntil",
    "RegistrationStep", "AccountStatus", "VerificationStatus",
    "RejectionReason", "RejectedAt", "RejectionCount", "CanReapplyAt",
    "DocumentRetakeJson", "IsFirstLogin", "TermsAcceptedAt",
    "CreatedAt", "UpdatedAt", "IsDeleted", "DeletedAt",
    "PasswordResetOtpHash", "PasswordResetOtpExpiresAt", "PasswordResetOtpAttempts",
    "RfidTagId", "RfidStatus", "RfidSuspendedUntil", "RfidSuspendedFrom"
)
VALUES
    -- 1. Student, car.
    ('11111111-1111-1111-1111-111111111101', 'Ana Reyes', 'tester1@gmail.com', TRUE,
     crypt('tester123!', gen_salt('bf', 11)),
     'Local', NULL, 'User', 'Student',
     '02000123456', 'BSIT 4A', TIMESTAMPTZ '2027-03-31 00:00:00+00',
     'Completed', 'Active', 'Passed',
     NULL, NULL, 0, NULL,
     NULL, FALSE, NOW(),
     NOW(), NOW(), FALSE, NULL,
     NULL, NULL, 0,
     '0004512301', 'Active', NULL, NULL),

    -- 2. Student, motorcycle. Motorcycle slots outnumber car slots 8 to 2 per
    --    gate, so this is the allocation path that actually gets exercised.
    ('11111111-1111-1111-1111-111111111102', 'Mark Dela Cruz', 'tester2@gmail.com', TRUE,
     crypt('tester123!', gen_salt('bf', 11)),
     'Local', NULL, 'User', 'Student',
     '02000123457', 'BSCS 3B', TIMESTAMPTZ '2027-03-31 00:00:00+00',
     'Completed', 'Active', 'Passed',
     NULL, NULL, 0, NULL,
     NULL, FALSE, NOW(),
     NOW(), NOW(), FALSE, NULL,
     NULL, NULL, 0,
     '0004512302', 'Active', NULL, NULL),

    -- 3. Faculty, car. No student number and no enrolment expiry — faculty have
    --    no RAF, which is the whole reason Affiliation exists as its own column:
    --    without it, a blank StudentNumber cannot be told apart from a student
    --    whose form would not read.
    ('11111111-1111-1111-1111-111111111103', 'Grace Lim', 'tester3@gmail.com', TRUE,
     crypt('tester123!', gen_salt('bf', 11)),
     'Local', NULL, 'User', 'Faculty',
     NULL, NULL, NULL,
     'Completed', 'Active', 'Passed',
     NULL, NULL, 0, NULL,
     NULL, FALSE, NOW(),
     NOW(), NOW(), FALSE, NULL,
     NULL, NULL, 0,
     '0004512303', 'Active', NULL, NULL)

ON CONFLICT ("Email") DO UPDATE SET
    "FullName"             = EXCLUDED."FullName",
    "IsEmailVerified"      = TRUE,
    "PasswordHash"         = EXCLUDED."PasswordHash",
    "AuthProvider"         = 'Local',
    "ExternalProviderId"   = NULL,
    "Role"                 = 'User',
    "Affiliation"          = EXCLUDED."Affiliation",
    "StudentNumber"        = EXCLUDED."StudentNumber",
    "Section"              = EXCLUDED."Section",
    "EnrollmentValidUntil" = EXCLUDED."EnrollmentValidUntil",
    -- The four columns that together mean "approved". Reset unconditionally so
    -- an account left mid-rejection or mid-retake by earlier testing comes back
    -- clean rather than half-blocked.
    "RegistrationStep"     = 'Completed',
    "AccountStatus"        = 'Active',
    "VerificationStatus"   = 'Passed',
    "DocumentRetakeJson"   = NULL,
    "RejectionReason"      = NULL,
    "RejectedAt"           = NULL,
    "RejectionCount"       = 0,
    "CanReapplyAt"         = NULL,
    "IsFirstLogin"         = FALSE,
    "TermsAcceptedAt"      = COALESCE("Users"."TermsAcceptedAt", NOW()),
    "IsDeleted"            = FALSE,
    "DeletedAt"            = NULL,
    "RfidTagId"            = EXCLUDED."RfidTagId",
    "RfidStatus"           = 'Active',
    "RfidSuspendedUntil"   = NULL,
    "RfidSuspendedFrom"    = NULL,
    "UpdatedAt"            = NOW();


-- ---------------------------------------------------------------------------
--  Vehicles
-- ---------------------------------------------------------------------------
--  Plates are stored uppercase with spaces and dashes stripped, which is what
--  IdentifierNormalizer.NormalizePlate produces. A gate camera reads "ABC1234"
--  while a human writes "ABC 1234"; storing the human form is how a valid card
--  gets refused at a barrier with nothing anywhere to explain why.
--
--  UserId is looked up by email rather than hard-coded, so this still attaches
--  to the right person if an account already existed under a different Id and
--  the INSERT above took the ON CONFLICT branch.
--
--  RegistrationRenewalMonth comes from the plate's last digit under the LTO's
--  staggered scheme (1 = January … 9 = September, 0 = October), and
--  RegistrationValidThrough is the next time that month falls due, through to
--  its last day — the same values RegistrationRenewal.DeriveExpiry() would
--  compute from a receipt dated today.

INSERT INTO "vehicles" (
    "Id", "PlateNumber", "VehicleType", "Brand", "Model", "Color",
    "RegistrationValidThrough", "RegistrationRenewalMonth", "CreatedAt", "UserId"
)
SELECT v."Id", v."PlateNumber", v."VehicleType", v."Brand", v."Model", v."Color",
       v."RegistrationValidThrough", v."RegistrationRenewalMonth", NOW(), u."Id"
FROM (
    VALUES
        ('22222222-2222-2222-2222-222222222201'::uuid, 'ABC1234', 'Car',        'Toyota', 'Vios',      'Silver',
         TIMESTAMPTZ '2027-04-30 00:00:00+00', 4, 'tester1@gmail.com'),
        ('22222222-2222-2222-2222-222222222202'::uuid, 'XYZ5678', 'Motorcycle', 'Honda',  'Click 125i', 'Red',
         TIMESTAMPTZ '2027-08-31 00:00:00+00', 8, 'tester2@gmail.com'),
        ('22222222-2222-2222-2222-222222222203'::uuid, 'DEF9012', 'Car',        'Toyota', 'Innova',    'White',
         TIMESTAMPTZ '2027-02-28 00:00:00+00', 2, 'tester3@gmail.com')
) AS v("Id", "PlateNumber", "VehicleType", "Brand", "Model", "Color",
       "RegistrationValidThrough", "RegistrationRenewalMonth", "Email")
JOIN "Users" u ON u."Email" = v."Email"

ON CONFLICT ("PlateNumber") DO UPDATE SET
    "VehicleType"              = EXCLUDED."VehicleType",
    "Brand"                    = EXCLUDED."Brand",
    "Model"                    = EXCLUDED."Model",
    "Color"                    = EXCLUDED."Color",
    "RegistrationValidThrough" = EXCLUDED."RegistrationValidThrough",
    "RegistrationRenewalMonth" = EXCLUDED."RegistrationRenewalMonth"
-- Guard, not decoration. PlateNumber is globally unique because ALPR looks a
-- plate up and must get back exactly one vehicle, so without this a re-run
-- would silently move a real user's plate onto a test account.
WHERE "vehicles"."UserId" = EXCLUDED."UserId";


-- ---------------------------------------------------------------------------
--  Check what landed
-- ---------------------------------------------------------------------------

SELECT u."Email",
       u."FullName",
       u."Affiliation",
       u."AccountStatus",
       u."RegistrationStep",
       u."RfidTagId",
       u."RfidStatus",
       v."PlateNumber",
       v."VehicleType",
       v."RegistrationValidThrough"::date AS "OR valid through"
FROM "Users" u
LEFT JOIN "vehicles" v ON v."UserId" = u."Id"
WHERE u."Email" IN ('tester1@gmail.com', 'tester2@gmail.com', 'tester3@gmail.com')
ORDER BY u."Email";


-- ============================================================================
--  Sign-in details
--  ---------------
--    tester1@gmail.com / tester123!   Ana Reyes    — Student, Car ABC1234
--    tester2@gmail.com / tester123!   Mark Dela Cruz — Student, Motorcycle XYZ5678
--    tester3@gmail.com / tester123!   Grace Lim    — Faculty, Car DEF9012
--
--  All three sign in on the mobile app. No documents, no OTP, no admin
--  approval — they are already past all of it.
-- ============================================================================


-- ---------------------------------------------------------------------------
--  Cleanup, when the testing is done
-- ---------------------------------------------------------------------------
--  Vehicles, documents and parking logs cascade from the user, so deleting the
--  three accounts is enough. Left commented so a stray Run cannot fire it.
--
--  DELETE FROM "Users"
--  WHERE "Email" IN ('tester1@gmail.com', 'tester2@gmail.com', 'tester3@gmail.com');

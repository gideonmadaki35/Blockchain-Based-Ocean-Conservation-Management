;; Fishing Activity Contract
;; Records and manages commercial fishing operations

(define-map fishing-permits
  { permit-id: uint }
  {
    vessel-name: (string-ascii 100),
    operator: principal,
    zone-id: uint,
    valid-from: uint,
    valid-until: uint,
    quota-kg: uint,
    active: bool
  }
)

(define-map fishing-activities
  { activity-id: uint }
  {
    permit-id: uint,
    catch-amount-kg: uint,
    fish-species: (string-ascii 100),
    fishing-date: uint,
    location: (string-ascii 200),
    reported-by: principal,
    verified: bool
  }
)

(define-map permit-usage
  { permit-id: uint }
  {
    total-catch-kg: uint,
    remaining-quota-kg: uint,
    activities-count: uint
  }
)

(define-data-var next-permit-id uint u1)
(define-data-var next-activity-id uint u1)

;; Error constants
(define-constant ERR-PERMIT-NOT-FOUND (err u300))
(define-constant ERR-PERMIT-EXPIRED (err u301))
(define-constant ERR-QUOTA-EXCEEDED (err u302))
(define-constant ERR-ACTIVITY-NOT-FOUND (err u303))

;; Issue a fishing permit
(define-public (issue-fishing-permit
  (vessel-name (string-ascii 100))
  (operator principal)
  (zone-id uint)
  (valid-until uint)
  (quota-kg uint))
  (let ((permit-id (var-get next-permit-id)))
    (map-set fishing-permits
      { permit-id: permit-id }
      {
        vessel-name: vessel-name,
        operator: operator,
        zone-id: zone-id,
        valid-from: block-height,
        valid-until: valid-until,
        quota-kg: quota-kg,
        active: true
      }
    )
    (map-set permit-usage
      { permit-id: permit-id }
      {
        total-catch-kg: u0,
        remaining-quota-kg: quota-kg,
        activities-count: u0
      }
    )
    (var-set next-permit-id (+ permit-id u1))
    (ok permit-id)
  )
)

;; Record fishing activity
(define-public (record-fishing-activity
  (permit-id uint)
  (catch-amount-kg uint)
  (fish-species (string-ascii 100))
  (location (string-ascii 200)))
  (match (map-get? fishing-permits { permit-id: permit-id })
    permit-data
    (if (and (get active permit-data) (<= block-height (get valid-until permit-data)))
      (match (map-get? permit-usage { permit-id: permit-id })
        usage-data
        (if (<= catch-amount-kg (get remaining-quota-kg usage-data))
          (let ((activity-id (var-get next-activity-id)))
            (map-set fishing-activities
              { activity-id: activity-id }
              {
                permit-id: permit-id,
                catch-amount-kg: catch-amount-kg,
                fish-species: fish-species,
                fishing-date: block-height,
                location: location,
                reported-by: tx-sender,
                verified: false
              }
            )
            (map-set permit-usage
              { permit-id: permit-id }
              {
                total-catch-kg: (+ (get total-catch-kg usage-data) catch-amount-kg),
                remaining-quota-kg: (- (get remaining-quota-kg usage-data) catch-amount-kg),
                activities-count: (+ (get activities-count usage-data) u1)
              }
            )
            (var-set next-activity-id (+ activity-id u1))
            (ok activity-id)
          )
          ERR-QUOTA-EXCEEDED
        )
        ERR-PERMIT-NOT-FOUND
      )
      ERR-PERMIT-EXPIRED
    )
    ERR-PERMIT-NOT-FOUND
  )
)

;; Verify fishing activity
(define-public (verify-fishing-activity (activity-id uint))
  (match (map-get? fishing-activities { activity-id: activity-id })
    activity-data (begin
      (map-set fishing-activities
        { activity-id: activity-id }
        (merge activity-data { verified: true })
      )
      (ok true)
    )
    ERR-ACTIVITY-NOT-FOUND
  )
)

;; Get permit information
(define-read-only (get-permit (permit-id uint))
  (map-get? fishing-permits { permit-id: permit-id })
)

;; Get permit usage
(define-read-only (get-permit-usage (permit-id uint))
  (map-get? permit-usage { permit-id: permit-id })
)

;; Get fishing activity
(define-read-only (get-fishing-activity (activity-id uint))
  (map-get? fishing-activities { activity-id: activity-id })
)

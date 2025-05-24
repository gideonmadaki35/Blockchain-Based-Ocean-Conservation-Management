;; Marine Area Verification Contract
;; Validates and manages protected marine zones

(define-map protected-zones
  { zone-id: uint }
  {
    name: (string-ascii 100),
    coordinates: (string-ascii 200),
    size-sqkm: uint,
    protection-level: (string-ascii 50),
    verified: bool,
    created-at: uint,
    verifier: principal
  }
)

(define-map zone-permissions
  { zone-id: uint, user: principal }
  { can-access: bool, role: (string-ascii 20) }
)

(define-data-var next-zone-id uint u1)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ZONE-NOT-FOUND (err u101))
(define-constant ERR-INVALID-COORDINATES (err u102))

;; Create a new protected zone
(define-public (create-protected-zone
  (name (string-ascii 100))
  (coordinates (string-ascii 200))
  (size-sqkm uint)
  (protection-level (string-ascii 50)))
  (let ((zone-id (var-get next-zone-id)))
    (map-set protected-zones
      { zone-id: zone-id }
      {
        name: name,
        coordinates: coordinates,
        size-sqkm: size-sqkm,
        protection-level: protection-level,
        verified: false,
        created-at: block-height,
        verifier: tx-sender
      }
    )
    (var-set next-zone-id (+ zone-id u1))
    (ok zone-id)
  )
)

;; Verify a protected zone
(define-public (verify-zone (zone-id uint))
  (match (map-get? protected-zones { zone-id: zone-id })
    zone-data (begin
      (map-set protected-zones
        { zone-id: zone-id }
        (merge zone-data { verified: true, verifier: tx-sender })
      )
      (ok true)
    )
    ERR-ZONE-NOT-FOUND
  )
)

;; Get zone information
(define-read-only (get-zone (zone-id uint))
  (map-get? protected-zones { zone-id: zone-id })
)

;; Check if zone is verified
(define-read-only (is-zone-verified (zone-id uint))
  (match (map-get? protected-zones { zone-id: zone-id })
    zone-data (ok (get verified zone-data))
    ERR-ZONE-NOT-FOUND
  )
)

;; Grant access permissions to a zone
(define-public (grant-zone-access (zone-id uint) (user principal) (role (string-ascii 20)))
  (begin
    (map-set zone-permissions
      { zone-id: zone-id, user: user }
      { can-access: true, role: role }
    )
    (ok true)
  )
)

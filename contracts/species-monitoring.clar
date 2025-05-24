;; Species Monitoring Contract
;; Tracks marine life populations and biodiversity

(define-map species-records
  { record-id: uint }
  {
    species-name: (string-ascii 100),
    zone-id: uint,
    population-count: uint,
    health-status: (string-ascii 50),
    observation-date: uint,
    observer: principal,
    verified: bool
  }
)

(define-map species-population-trends
  { species-name: (string-ascii 100), zone-id: uint }
  {
    total-observations: uint,
    average-population: uint,
    trend: (string-ascii 20),
    last-updated: uint
  }
)

(define-data-var next-record-id uint u1)

;; Error constants
(define-constant ERR-RECORD-NOT-FOUND (err u200))
(define-constant ERR-INVALID-COUNT (err u201))

;; Record a species observation
(define-public (record-species-observation
  (species-name (string-ascii 100))
  (zone-id uint)
  (population-count uint)
  (health-status (string-ascii 50)))
  (let ((record-id (var-get next-record-id)))
    (if (> population-count u0)
      (begin
        (map-set species-records
          { record-id: record-id }
          {
            species-name: species-name,
            zone-id: zone-id,
            population-count: population-count,
            health-status: health-status,
            observation-date: block-height,
            observer: tx-sender,
            verified: false
          }
        )
        (var-set next-record-id (+ record-id u1))
        (update-population-trend species-name zone-id population-count)
        (ok record-id)
      )
      ERR-INVALID-COUNT
    )
  )
)

;; Verify a species observation
(define-public (verify-observation (record-id uint))
  (match (map-get? species-records { record-id: record-id })
    record-data (begin
      (map-set species-records
        { record-id: record-id }
        (merge record-data { verified: true })
      )
      (ok true)
    )
    ERR-RECORD-NOT-FOUND
  )
)

;; Update population trend
(define-private (update-population-trend
  (species-name (string-ascii 100))
  (zone-id uint)
  (new-count uint))
  (match (map-get? species-population-trends { species-name: species-name, zone-id: zone-id })
    existing-trend
    (let ((new-total (+ (get total-observations existing-trend) u1))
          (new-avg (/ (+ (* (get average-population existing-trend) (get total-observations existing-trend)) new-count) new-total)))
      (map-set species-population-trends
        { species-name: species-name, zone-id: zone-id }
        {
          total-observations: new-total,
          average-population: new-avg,
          trend: (if (> new-count (get average-population existing-trend)) "increasing" "decreasing"),
          last-updated: block-height
        }
      )
    )
    (map-set species-population-trends
      { species-name: species-name, zone-id: zone-id }
      {
        total-observations: u1,
        average-population: new-count,
        trend: "stable",
        last-updated: block-height
      }
    )
  )
)

;; Get species record
(define-read-only (get-species-record (record-id uint))
  (map-get? species-records { record-id: record-id })
)

;; Get population trend
(define-read-only (get-population-trend (species-name (string-ascii 100)) (zone-id uint))
  (map-get? species-population-trends { species-name: species-name, zone-id: zone-id })
)

;; Conservation Initiative Contract
;; Manages protection efforts and conservation projects

(define-map conservation-projects
  { project-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 500),
    zone-id: uint,
    project-type: (string-ascii 50),
    budget: uint,
    start-date: uint,
    end-date: uint,
    manager: principal,
    status: (string-ascii 20),
    participants-count: uint
  }
)

(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 300),
    target-date: uint,
    completed: bool,
    completion-date: (optional uint),
    verified-by: (optional principal)
  }
)

(define-map project-participants
  { project-id: uint, participant: principal }
  {
    role: (string-ascii 50),
    joined-date: uint,
    contribution-hours: uint,
    active: bool
  }
)

(define-data-var next-project-id uint u1)

;; Error constants
(define-constant ERR-PROJECT-NOT-FOUND (err u400))
(define-constant ERR-MILESTONE-NOT-FOUND (err u401))
(define-constant ERR-NOT-PROJECT-MANAGER (err u402))
(define-constant ERR-ALREADY-PARTICIPANT (err u403))

;; Create a conservation project
(define-public (create-conservation-project
  (title (string-ascii 200))
  (description (string-ascii 500))
  (zone-id uint)
  (project-type (string-ascii 50))
  (budget uint)
  (end-date uint))
  (let ((project-id (var-get next-project-id)))
    (map-set conservation-projects
      { project-id: project-id }
      {
        title: title,
        description: description,
        zone-id: zone-id,
        project-type: project-type,
        budget: budget,
        start-date: block-height,
        end-date: end-date,
        manager: tx-sender,
        status: "active",
        participants-count: u1
      }
    )
    (map-set project-participants
      { project-id: project-id, participant: tx-sender }
      {
        role: "manager",
        joined-date: block-height,
        contribution-hours: u0,
        active: true
      }
    )
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

;; Add project milestone
(define-public (add-project-milestone
  (project-id uint)
  (milestone-id uint)
  (description (string-ascii 300))
  (target-date uint))
  (match (map-get? conservation-projects { project-id: project-id })
    project-data
    (if (is-eq (get manager project-data) tx-sender)
      (begin
        (map-set project-milestones
          { project-id: project-id, milestone-id: milestone-id }
          {
            description: description,
            target-date: target-date,
            completed: false,
            completion-date: none,
            verified-by: none
          }
        )
        (ok true)
      )
      ERR-NOT-PROJECT-MANAGER
    )
    ERR-PROJECT-NOT-FOUND
  )
)

;; Complete a milestone
(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (match (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
    milestone-data
    (begin
      (map-set project-milestones
        { project-id: project-id, milestone-id: milestone-id }
        (merge milestone-data
          {
            completed: true,
            completion-date: (some block-height),
            verified-by: (some tx-sender)
          }
        )
      )
      (ok true)
    )
    ERR-MILESTONE-NOT-FOUND
  )
)

;; Join conservation project
(define-public (join-project (project-id uint) (role (string-ascii 50)))
  (match (map-get? conservation-projects { project-id: project-id })
    project-data
    (match (map-get? project-participants { project-id: project-id, participant: tx-sender })
      existing-participant ERR-ALREADY-PARTICIPANT
      (begin
        (map-set project-participants
          { project-id: project-id, participant: tx-sender }
          {
            role: role,
            joined-date: block-height,
            contribution-hours: u0,
            active: true
          }
        )
        (map-set conservation-projects
          { project-id: project-id }
          (merge project-data
            { participants-count: (+ (get participants-count project-data) u1) }
          )
        )
        (ok true)
      )
    )
    ERR-PROJECT-NOT-FOUND
  )
)

;; Update contribution hours
(define-public (update-contribution-hours (project-id uint) (hours uint))
  (match (map-get? project-participants { project-id: project-id, participant: tx-sender })
    participant-data
    (begin
      (map-set project-participants
        { project-id: project-id, participant: tx-sender }
        (merge participant-data
          { contribution-hours: (+ (get contribution-hours participant-data) hours) }
        )
      )
      (ok true)
    )
    ERR-PROJECT-NOT-FOUND
  )
)

;; Get project information
(define-read-only (get-project (project-id uint))
  (map-get? conservation-projects { project-id: project-id })
)

;; Get milestone information
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
)

;; Get participant information
(define-read-only (get-participant (project-id uint) (participant principal))
  (map-get? project-participants { project-id: project-id, participant: participant })
)

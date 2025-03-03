;; PeerFund - Decentralized peer funding platform

;; Constants
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-DEADLINE-PASSED (err u103))
(define-constant ERR-GOAL-NOT-REACHED (err u104))
(define-constant ERR-ALREADY-CLAIMED (err u105))
(define-constant ERR-INVALID-DURATION (err u106))
(define-constant ERR-CAMPAIGN-INACTIVE (err u107))

;; Configuration
(define-constant MAX-DURATION u52560) ;; Max campaign duration (~1 year in blocks)
(define-constant MIN-GOAL u1000000) ;; Minimum campaign goal (1M uSTX)

;; Data variables
(define-data-var campaign-id uint u0)

;; Campaign data structure 
(define-map campaigns uint {
  owner: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  goal: uint,
  deadline: uint,
  raised: uint,
  active: bool
})

;; Track contributions
(define-map contributions {campaign-id: uint, contributor: principal} uint)

;; Track withdrawals and refunds
(define-map claims {campaign-id: uint, claimer: principal} bool)

;; Events
(define-public (emit-campaign-created (campaign-id uint) (owner principal))
  (print {event: "campaign-created", campaign-id: campaign-id, owner: owner})
  (ok true))

(define-public (emit-contribution (campaign-id uint) (contributor principal) (amount uint))
  (print {event: "contribution", campaign-id: campaign-id, contributor: contributor, amount: amount})
  (ok true))

;; Campaign Management Functions

(define-public (create-campaign 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (goal uint)
    (duration uint))
  (let ((campaign-num (+ (var-get campaign-id) u1)))
    ;; Input validation
    (asserts! (>= goal MIN-GOAL) ERR-INVALID-AMOUNT)
    (asserts! (<= duration MAX-DURATION) ERR-INVALID-DURATION)
    
    (map-set campaigns campaign-num {
      owner: tx-sender,
      title: title,
      description: description, 
      goal: goal,
      deadline: (+ block-height duration),
      raised: u0,
      active: true
    })
    (var-set campaign-id campaign-num)
    (try! (emit-campaign-created campaign-num tx-sender))
    (ok campaign-num)
  )
)

(define-public (update-campaign-details 
    (campaign-num uint)
    (new-title (string-ascii 100))
    (new-description (string-ascii 500)))
  (let ((campaign (unwrap! (map-get? campaigns campaign-num) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner campaign)) ERR-UNAUTHORIZED)
    (asserts! (get active campaign) ERR-CAMPAIGN-INACTIVE)
    (asserts! (<= block-height (get deadline campaign)) ERR-DEADLINE-PASSED)
    
    (map-set campaigns campaign-num 
      (merge campaign {
        title: new-title,
        description: new-description
      }))
    (ok true)
  )
)

(define-public (cancel-campaign (campaign-num uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-num) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner campaign)) ERR-UNAUTHORIZED)
    (asserts! (get active campaign) ERR-CAMPAIGN-INACTIVE)
    (asserts! (is-eq (get raised campaign) u0) ERR-INVALID-AMOUNT)
    
    (map-set campaigns campaign-num 
      (merge campaign {active: false}))
    (ok true)
  )
)

;; Contribution Functions

(define-public (contribute (campaign-num uint) (amount uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-num) ERR-NOT-FOUND)))
    (asserts! (get active campaign) ERR-CAMPAIGN-INACTIVE)
    (asserts! (<= block-height (get deadline campaign)) ERR-DEADLINE-PASSED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set campaigns campaign-num 
      (merge campaign {raised: (+ (get raised campaign) amount)}))
    (map-set contributions {campaign-id: campaign-num, contributor: tx-sender}
      (+ (default-to u0 (map-get? contributions {campaign-id: campaign-num, contributor: tx-sender})) amount))
    
    (try! (emit-contribution campaign-num tx-sender amount))
    (ok true)
  )
)

;; Fund Management Functions

(define-public (withdraw-funds (campaign-num uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-num) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner campaign)) ERR-UNAUTHORIZED)
    (asserts! (>= (get raised campaign) (get goal campaign)) ERR-GOAL-NOT-REACHED)
    (asserts! (not (default-to false (map-get? claims {campaign-id: campaign-num, claimer: tx-sender}))) ERR-ALREADY-CLAIMED)
    
    (try! (as-contract (stx-transfer? (get raised campaign) tx-sender (get owner campaign))))
    (map-set claims {campaign-id: campaign-num, claimer: tx-sender} true)
    (map-set campaigns campaign-num (merge campaign {active: false}))
    (ok true)
  )
)

(define-public (get-refund (campaign-num uint))
  (let (
    (campaign (unwrap! (map-get? campaigns campaign-num) ERR-NOT-FOUND))
    (contribution (default-to u0 (map-get? contributions {campaign-id: campaign-num, contributor: tx-sender})))
  )
    (asserts! (> block-height (get deadline campaign)) ERR-DEADLINE-PASSED)
    (asserts! (< (get raised campaign) (get goal campaign)) ERR-GOAL-NOT-REACHED)
    (asserts! (> contribution u0) ERR-NOT-FOUND)
    (asserts! (not (default-to false (map-get? claims {campaign-id: campaign-num, claimer: tx-sender}))) ERR-ALREADY-CLAIMED)
    
    (try! (as-contract (stx-transfer? contribution tx-sender tx-sender)))
    (map-set claims {campaign-id: campaign-num, claimer: tx-sender} true)
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-campaign-info (campaign-num uint))
  (ok (unwrap! (map-get? campaigns campaign-num) ERR-NOT-FOUND))
)

(define-read-only (get-contribution (campaign-num uint) (contributor principal))
  (ok (default-to u0 (map-get? contributions {campaign-id: campaign-num, contributor: contributor})))
)

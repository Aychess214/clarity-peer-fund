;; PeerFund - Decentralized peer funding platform

;; Constants
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-DEADLINE-PASSED (err u103))
(define-constant ERR-GOAL-NOT-REACHED (err u104))
(define-constant ERR-ALREADY-CLAIMED (err u105))

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

;; Create new campaign
(define-public (create-campaign 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (goal uint)
    (duration uint))
  (let ((campaign-num (+ (var-get campaign-id) u1)))
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
    (ok campaign-num)
  )
)

;; Contribute to campaign
(define-public (contribute (campaign-num uint) (amount uint))
  (let ((campaign (unwrap! (map-get? campaigns campaign-num) ERR-NOT-FOUND)))
    (asserts! (get active campaign) ERR-NOT-FOUND)
    (asserts! (<= block-height (get deadline campaign)) ERR-DEADLINE-PASSED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set campaigns campaign-num 
      (merge campaign {raised: (+ (get raised campaign) amount)}))
    (map-set contributions {campaign-id: campaign-num, contributor: tx-sender}
      (+ (default-to u0 (map-get? contributions {campaign-id: campaign-num, contributor: tx-sender})) amount))
    (ok true)
  )
)

;; Withdraw funds (campaign owner)
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

;; Get refund (contributor)
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

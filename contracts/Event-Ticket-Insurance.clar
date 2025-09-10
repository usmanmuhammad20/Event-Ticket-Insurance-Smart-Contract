(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-EVENT-NOT-ACTIVE (err u104))
(define-constant ERR-EVENT-CANCELED (err u105))
(define-constant ERR-REFUND-CLAIMED (err u106))
(define-constant ERR-ORACLE-UNAUTHORIZED (err u107))

(define-constant ERR-TRANSFER-NOT-FOUND (err u108))
(define-constant ERR-TRANSFER-PRICE-MISMATCH (err u109))
(define-constant ERR-TICKET-ALREADY-LISTED (err u110))

(define-constant PRICE-MULTIPLIER-BASE u100)
(define-constant MAX-PRICE-INCREASE u200)
(define-constant URGENCY-BLOCKS u1000)

(define-data-var next-event-id uint u1)
(define-data-var next-ticket-id uint u1)

(define-map authorized-oracles principal bool)
(define-map events uint {
  organizer: principal,
  name: (string-ascii 100),
  date: uint,
  ticket-price: uint,
  insurance-fee: uint,
  total-tickets: uint,
  sold-tickets: uint,
  status: (string-ascii 20)
})

(define-map tickets uint {
  event-id: uint,
  buyer: principal,
  purchase-block: uint,
  has-insurance: bool,
  refund-claimed: bool
})

(define-map event-tickets uint (list 1000 uint))

(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (ok (map-set authorized-oracles oracle true))
  )
)

(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (ok (map-delete authorized-oracles oracle))
  )
)

(define-public (create-event (name (string-ascii 100)) (date uint) (ticket-price uint) (insurance-fee uint) (total-tickets uint))
  (let ((event-id (var-get next-event-id)))
    (asserts! (> ticket-price u0) ERR-INVALID-AMOUNT)
    (asserts! (> total-tickets u0) ERR-INVALID-AMOUNT)
    (asserts! (> date stacks-block-height) ERR-INVALID-AMOUNT)
    (map-set events event-id {
      organizer: tx-sender,
      name: name,
      date: date,
      ticket-price: ticket-price,
      insurance-fee: insurance-fee,
      total-tickets: total-tickets,
      sold-tickets: u0,
      status: "active"
    })
    (map-set event-tickets event-id (list))
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

(define-public (buy-ticket (event-id uint) (with-insurance bool))
  (let (
    (event (unwrap! (map-get? events event-id) ERR-NOT-FOUND))
    (ticket-id (var-get next-ticket-id))
    (total-cost (if with-insurance 
                   (+ (get ticket-price event) (get insurance-fee event))
                   (get ticket-price event)))
  )
    (asserts! (is-eq (get status event) "active") ERR-EVENT-NOT-ACTIVE)
    (asserts! (< (get sold-tickets event) (get total-tickets event)) ERR-INVALID-AMOUNT)
    (asserts! (> (stx-get-balance tx-sender) total-cost) ERR-INVALID-AMOUNT)
    
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    (map-set tickets ticket-id {
      event-id: event-id,
      buyer: tx-sender,
      purchase-block: stacks-block-height,
      has-insurance: with-insurance,
      refund-claimed: false
    })
    
    (map-set events event-id (merge event {
      sold-tickets: (+ (get sold-tickets event) u1)
    }))
    
    (let ((current-tickets (default-to (list) (map-get? event-tickets event-id))))
      (map-set event-tickets event-id (unwrap! (as-max-len? (append current-tickets ticket-id) u1000) ERR-INVALID-AMOUNT))
    )
    
    (var-set next-ticket-id (+ ticket-id u1))
    (ok ticket-id)
  )
)

(define-public (update-event-status (event-id uint) (new-status (string-ascii 20)))
  (let ((event (unwrap! (map-get? events event-id) ERR-NOT-FOUND)))
    (asserts! (default-to false (map-get? authorized-oracles tx-sender)) ERR-ORACLE-UNAUTHORIZED)
    (map-set events event-id (merge event { status: new-status }))
    (ok true)
  )
)

(define-public (claim-refund (ticket-id uint))
  (let (
    (ticket (unwrap! (map-get? tickets ticket-id) ERR-NOT-FOUND))
    (event (unwrap! (map-get? events (get event-id ticket)) ERR-NOT-FOUND))
  )
    (asserts! (is-eq (get buyer ticket) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (get has-insurance ticket) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status event) "canceled") ERR-EVENT-NOT-ACTIVE)
    (asserts! (not (get refund-claimed ticket)) ERR-REFUND-CLAIMED)
    
    (let ((refund-amount (+ (get ticket-price event) (get insurance-fee event))))
      (try! (as-contract (stx-transfer? refund-amount tx-sender (get buyer ticket))))
      (map-set tickets ticket-id (merge ticket { refund-claimed: true }))
      (ok refund-amount)
    )
  )
)

(define-public (withdraw-proceeds (event-id uint))
  (let ((event (unwrap! (map-get? events event-id) ERR-NOT-FOUND)))
    (asserts! (is-eq (get organizer event) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq (get status event) "completed") (is-eq (get status event) "active")) ERR-EVENT-CANCELED)
    (asserts! (> (get date event) stacks-block-height) ERR-INVALID-AMOUNT)
    
    (let ((total-revenue (* (get sold-tickets event) (get ticket-price event))))
      (try! (as-contract (stx-transfer? total-revenue tx-sender (get organizer event))))
      (ok total-revenue)
    )
  )
)

(define-read-only (get-event (event-id uint))
  (map-get? events event-id)
)

(define-read-only (get-ticket (ticket-id uint))
  (map-get? tickets ticket-id)
)

(define-read-only (get-event-tickets (event-id uint))
  (map-get? event-tickets event-id)
)

(define-read-only (is-oracle (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

(define-read-only (get-user-tickets (user principal))
  (filter is-user-ticket (map get-ticket-id (list 
    u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
  )))
)

(define-private (get-ticket-id (id uint))
  id
)

(define-private (is-user-ticket (ticket-id uint))
  (match (map-get? tickets ticket-id)
    ticket (is-eq (get buyer ticket) tx-sender)
    false
  )
)

(define-map ticket-transfers uint {
  seller: principal,
  price: uint,
  insurance-included: bool,
  listed-block: uint
})

(define-public (list-ticket-for-transfer (ticket-id uint) (price uint))
  (let (
    (ticket (unwrap! (map-get? tickets ticket-id) ERR-NOT-FOUND))
    (event (unwrap! (map-get? events (get event-id ticket)) ERR-NOT-FOUND))
  )
    (asserts! (is-eq (get buyer ticket) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq (get status event) "active") ERR-EVENT-NOT-ACTIVE)
    (asserts! (is-none (map-get? ticket-transfers ticket-id)) ERR-ALREADY-EXISTS)
    
    (map-set ticket-transfers ticket-id {
      seller: tx-sender,
      price: price,
      insurance-included: (get has-insurance ticket),
      listed-block: stacks-block-height
    })
    (ok true)
  )
)

(define-public (transfer-ticket (ticket-id uint))
  (let (
    (transfer (unwrap! (map-get? ticket-transfers ticket-id) ERR-TRANSFER-NOT-FOUND))
    (ticket (unwrap! (map-get? tickets ticket-id) ERR-NOT-FOUND))
    (transfer-price (get price transfer))
  )
    (asserts! (> (stx-get-balance tx-sender) transfer-price) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq tx-sender (get seller transfer))) ERR-UNAUTHORIZED)
    
    (try! (stx-transfer? transfer-price tx-sender (get seller transfer)))
    
    (map-set tickets ticket-id (merge ticket {
      buyer: tx-sender,
      purchase-block: stacks-block-height
    }))
    
    (map-delete ticket-transfers ticket-id)
    (ok ticket-id)
  )
)

(define-public (cancel-transfer-listing (ticket-id uint))
  (let ((transfer (unwrap! (map-get? ticket-transfers ticket-id) ERR-TRANSFER-NOT-FOUND)))
    (asserts! (is-eq (get seller transfer) tx-sender) ERR-UNAUTHORIZED)
    (map-delete ticket-transfers ticket-id)
    (ok true)
  )
)

(define-read-only (get-ticket-transfer (ticket-id uint))
  (map-get? ticket-transfers ticket-id)
)

(define-read-only (get-available-transfers)
  (filter is-valid-transfer (map get-transfer-id (list 
    u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
  )))
)

(define-private (get-transfer-id (id uint))
  id
)

(define-private (is-valid-transfer (ticket-id uint))
  (is-some (map-get? ticket-transfers ticket-id))
)


(define-map dynamic-pricing uint {
  base-price: uint,
  current-multiplier: uint,
  last-update-block: uint,
  demand-factor: uint
})

(define-public (enable-dynamic-pricing (event-id uint))
  (let ((event (unwrap! (map-get? events event-id) ERR-NOT-FOUND)))
    (asserts! (is-eq (get organizer event) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status event) "active") ERR-EVENT-NOT-ACTIVE)
    (map-set dynamic-pricing event-id {
      base-price: (get ticket-price event),
      current-multiplier: PRICE-MULTIPLIER-BASE,
      last-update-block: stacks-block-height,
      demand-factor: u0
    })
    (ok true)
  )
)

(define-public (update-ticket-price (event-id uint))
  (let (
    (event (unwrap! (map-get? events event-id) ERR-NOT-FOUND))
    (pricing (unwrap! (map-get? dynamic-pricing event-id) ERR-NOT-FOUND))
    (sold-percentage (/ (* (get sold-tickets event) u100) (get total-tickets event)))
    (blocks-until-event (if (> (get date event) stacks-block-height) 
                          (- (get date event) stacks-block-height) u0))
    (urgency-multiplier (if (< blocks-until-event URGENCY-BLOCKS)
                          (+ u100 (/ (* (- URGENCY-BLOCKS blocks-until-event) u50) URGENCY-BLOCKS))
                          u100))
    (demand-multiplier (+ u100 (/ sold-percentage u2)))
    (calculated-multiplier (* urgency-multiplier demand-multiplier))
    (new-multiplier (if (> calculated-multiplier MAX-PRICE-INCREASE) MAX-PRICE-INCREASE calculated-multiplier))
  )
    (asserts! (is-eq (get status event) "active") ERR-EVENT-NOT-ACTIVE)
    (map-set dynamic-pricing event-id (merge pricing {
      current-multiplier: new-multiplier,
      last-update-block: stacks-block-height,
      demand-factor: sold-percentage
    }))
    (ok new-multiplier)
  )
)

(define-read-only (get-current-ticket-price (event-id uint))
  (match (map-get? dynamic-pricing event-id)
    pricing (let ((event (unwrap! (map-get? events event-id) ERR-NOT-FOUND)))
              (ok (/ (* (get base-price pricing) (get current-multiplier pricing)) u100)))
    (match (map-get? events event-id)
      event (ok (get ticket-price event))
      ERR-NOT-FOUND
    )
  )
)

(define-read-only (get-pricing-details (event-id uint))
  (map-get? dynamic-pricing event-id)
)

(define-read-only (calculate-total-cost-with-pricing (event-id uint) (with-insurance bool))
  (let (
    (current-price (unwrap! (get-current-ticket-price event-id) ERR-NOT-FOUND))
    (event (unwrap! (map-get? events event-id) ERR-NOT-FOUND))
  )
    (ok (if with-insurance 
          (+ current-price (get insurance-fee event))
          current-price))
  )
)
(define-trait token-trait
    ((transfer-from? (principal principal uint) (response uint uint))
))


(define-constant period-duration  u17280)
(define-constant voting-period-length  u35)
(define-constant grace-period-length  u35)
(define-constant proposal-deposit u100000)
(define-constant dilution-bound  u10)
(define-constant processing-reward  u10000)
(define-constant summoning-time  (unwrap-panic (get-block-info? time block-height)))

(define-constant deposit-token 'ST398K1WZTBVY6FE2YEHM6HP20VSNVSSPJTW0D53M.wrapped-stx)

(define-constant max-voting-period-length u1000000000000000000)
(define-constant max-grace-period-length u1000000000000000000)
(define-constant max-dilution-bound u1000000000000000000)
(define-constant max-number-of-shares-and-loot u1000000000000000000)
(define-constant max-token-whitelist-count 400)
(define-constant max-token-guild-bank-count u200)

(define-constant guild (as-contract tx-sender))
(define-constant total (as-contract tx-sender)) ;; TODO some unused address
(define-constant escrow (as-contract tx-sender)) ;; TODO some unused address

(define-data-var proposal-count uint u0)
(define-data-var total-shares uint u1) ;; must be created with one member
(define-data-var total-loot uint u0)

(define-data-var total-guild-bank-token-count uint u0)

(define-map user-token-balance
  ((user principal) (token principal))
  ((amount uint))
)

(define-map token-whitelist ((token principal)) ((approved bool)))
(define-data-var approved-tokens (list 400 principal)
  (list 'ST398K1WZTBVY6FE2YEHM6HP20VSNVSSPJTW0D53M.wrapped-token)
)

(begin
  (map-insert token-whitelist ((token 'ST398K1WZTBVY6FE2YEHM6HP20VSNVSSPJTW0D53M.wrapped-stx))
    ((approved true))
  )
)

(define-map proposed-to-whitelist ((token principal)) ((proposed bool)))
(define-map proposed-to-kick ((member principal)) ((proposed bool)))
(define-map members ((member principal))
  (
    (delegate-key principal)
    (shares uint)
    (loot uint)
    (highest-index-yes-vote uint)
    (jailed uint)
  )
)

(begin
  (map-insert members ((member 'ST398K1WZTBVY6FE2YEHM6HP20VSNVSSPJTW0D53M))
    (
      (delegate-key 'ST398K1WZTBVY6FE2YEHM6HP20VSNVSSPJTW0D53M)
      (shares u1)
      (loot u0)
      (highest-index-yes-vote u0)
      (jailed u0)
    )
  )
)

(define-map member-by-delegate-key ((delegate-key principal))
  (
    (member principal)
  )
)

(begin
 (map-insert member-by-delegate-key ((delegate-key 'ST398K1WZTBVY6FE2YEHM6HP20VSNVSSPJTW0D53M))
    ((member 'ST398K1WZTBVY6FE2YEHM6HP20VSNVSSPJTW0D53M))
  )
)

(define-map proposals ((index uint))
  (
    (applicant (optional principal))
    (proposer principal)
    (sponsor (optional principal))
    (shares-requested uint)
    (loot-requested uint)
    (tribute-offered uint)
    (tribute-token principal)
    (payment-requested uint)
    (payment-token principal)
    (starting-period uint)
    (yes-votes uint)
    (no-votes uint)
    (flags (list 6 bool))
    (details (buff 256))
    (max-total-shares-and-loot-at-yes-votes uint)
  )
)

(define-map votes-by-member ((proposal uint) (member principal))
  (
    (vote (optional bool))
  )
)

(define-data-var proposal-queue (list 100 uint) (list))

(define-private (unsafe-add-balance (user principal) (token principal) (amount uint))
  (begin
    (map-set user-token-balance ((user user) (token token))
      (
        (amount
          (+
            amount
           (default-to u0 (get amount (map-get? user-token-balance ((user user) (token token)))))
          )
        )
      )
    )

    (map-set user-token-balance ((user total) (token token))
      (
        (amount
          (+
            amount
            (default-to u0 (get amount (map-get? user-token-balance ((user user) (token token)))))
          )
        )
      )
    )
  )
)

(define-private (inc-proposal-count)
  (var-set proposal-count (+ u1 (var-get proposal-count)))
)

(define-private (add-proposal (user (optional principal)) (shares-requested uint) (loot-requested uint)
  (tribute-offered uint)
  (tribute-token <token-trait>)
  (payment-requested uint)
  (payment-token <token-trait>)
  (details (buff 256))
  (flags (list 6 bool))
  )
  (begin
    (map-insert proposals ((index (var-get proposal-count)))
      (
        (applicant user)
        (proposer tx-sender)
        (sponsor none)
        (shares-requested shares-requested)
        (loot-requested loot-requested)
        (tribute-offered tribute-offered)
        (tribute-token (contract-of tribute-token))
        (payment-requested payment-requested)
        (payment-token (contract-of payment-token))
        (starting-period u0)
        (yes-votes u0)
        (no-votes u0)
        (flags flags)
        (details details)
        (max-total-shares-and-loot-at-yes-votes u0)
      )
    )
    (inc-proposal-count)
    (var-get proposal-count)
  )
)

(define-private (contract-of (token <token-trait>))
  'ST398K1WZTBVY6FE2YEHM6HP20VSNVSSPJTW0D53M.wrapped-stx
)

(define-private (require-not-too-many-guild-tokens (amount uint) (token principal))
  (if (and
        (> amount u0)
        (is-eq u0 (default-to u0 (get amount (map-get? user-token-balance ((user guild) (token token))))))
      )
      (unwrap-panic (if (< (var-get total-guild-bank-token-count) max-token-guild-bank-count) (some true) none))
      true
  )
)

(define-public (submit-proposal
        (applicant principal)
        (shares-requested uint)
        (loot-requested uint)
        (tribute-offered uint)
        (tribute-token <token-trait>)
        (payment-requested uint)
        (payment-token <token-trait>)
        (details (buff 256)))
  (begin
    (unwrap-panic (if (< (+ shares-requested loot-requested) max-number-of-shares-and-loot) (some true) none))
    (unwrap-panic (map-get? token-whitelist ((token (contract-of tribute-token)))))
    (unwrap-panic (map-get? token-whitelist ((token (contract-of payment-token)))))
    (unwrap-panic (match (get jailed (map-get? members ((member applicant))))
                  jailed (if (is-eq jailed u0) (some true) none)
                  none
                )
    )
    (require-not-too-many-guild-tokens tribute-offered (contract-of tribute-token))

    (unwrap-panic (contract-call? tribute-token transfer-from? tx-sender (as-contract tx-sender) tribute-offered))
    (unsafe-add-balance escrow (contract-of tribute-token) tribute-offered)
    (ok (add-proposal (some applicant) shares-requested loot-requested tribute-offered tribute-token payment-requested payment-token details (list)))
  )
)

(define-public (submit-whitelist-proposal)
  (ok true)
)

(define-public (submit-guild-kick-proposal)
  (ok true)
)

(define-private (by-index (flag bool) (state (tuple (current-index uint) (requested-index uint) (result (optional bool)))))
  (tuple
    (current-index (+ (get current-index state) u1))
    (requested-index (get requested-index state))
    (result
      (if (is-eq (get current-index state) (get requested-index state))
        (some flag)
        (get result state)
      )
    )
  )
)

(define-private (get-flag (index uint) (list-of-flags (list 6 bool)))
  (get result
    (fold by-index list-of-flags (tuple (current-index u0) (requested-index index) (result none)))
  )
)

(define-private (requires-not-true (index uint) (flags (list 6 bool)))
  (unwrap-panic (match (get-flag index flags)
                      flag (if flag none (some true))
                      (some true)
                    )
  )
)

(define-private (not-jailed (optional-member (optional principal)))
  (match optional-member
    member
      (unwrap-panic
        (match (get jailed (map-get? members ((member member))))
          jailed (if (is-eq jailed u0) (some true) none)
          (some true)
        )
      )
    true
  )
)

(define-private (update-proposal (proposal-index uint)
(proposal (tuple
    (applicant (optional principal))
    (proposer principal)
    (sponsor (optional principal))
    (shares-requested uint)
    (loot-requested uint)
    (tribute-offered uint)
    (tribute-token principal)
    (payment-requested uint)
    (payment-token principal)
    (starting-period uint)
    (yes-votes uint)
    (no-votes uint)
    (flags (list 6 bool))
    (details (buff 256))
    (max-total-shares-and-loot-at-yes-votes uint)
  )) (starting-period uint) (sponsor (optional principal)))

  (map-set proposals ((index proposal-index))
        (
          (applicant (get applicant proposal))
          (proposer (get proposer proposal))
          (sponsor sponsor)
          (shares-requested (get shares-requested proposal))
          (loot-requested (get loot-requested proposal))
          (tribute-offered (get tribute-offered proposal))
          (tribute-token (get tribute-token proposal))
          (payment-requested (get payment-requested proposal))
          (payment-token (get payment-token proposal))
          (starting-period starting-period)
          (yes-votes u0)
          (no-votes u0)
          (flags (get flags proposal))
          (details (get details proposal))
          (max-total-shares-and-loot-at-yes-votes u0)
        )
      )
)

(define-public (sponsor-proposal (token <token-trait>) (proposal-index uint))
  (begin
    (unwrap-panic (if (is-eq (contract-of token) deposit-token) (some true) none))
    (unwrap-panic (contract-call? token transfer-from? tx-sender (as-contract tx-sender) proposal-deposit))
    (let ((proposal (unwrap-panic (map-get? proposals ((index proposal-index ))))))
      (begin
        (requires-not-true u0 (get flags proposal))
        (requires-not-true u3 (get flags proposal))
        (not-jailed (get applicant proposal))
        (require-not-too-many-guild-tokens (get tribute-offered proposal) (get tribute-token proposal))

        ;; handle whitelist sponsoring
        ;; handle kick sponsoring
        ;; set starting period

        (update-proposal proposal-index proposal u0 (get member (map-get? member-by-delegate-key ((delegate-key tx-sender)))))
        (append (var-get proposal-queue) proposal-index)
        (ok true)
      )
    )
  )
)

(define-public (submit-vote)
  (ok true)
)

(define-public (process-proposal)
  (ok true)
)

(define-public (process-whitelist-proposal)
  (ok true)
)

(define-public (process-guild-kick-proposal)
  (ok true)
)

(define-public (rage-quit)
  (ok true)
)

(define-public (rage-kick)
  (ok true)
)

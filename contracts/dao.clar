(define-trait token-trait
    ((transfer-from? (principal principal uint) (response uint uint)))
)

;; time of last block in seconds
(define-private (get-time)
   (unwrap-panic (get-block-info? time (- block-height u1)))
)

(define-constant period-duration  u17280)
(define-constant voting-period-length  u35)
(define-constant grace-period-length  u35)
(define-constant proposal-deposit u100000)
(define-constant dilution-bound  u10)
(define-constant processing-reward  u10000)
(define-constant summoning-time  (get-time))

(define-constant deposit-token .dao-token)

(define-constant max-voting-period-length u1000000000000000000)
(define-constant max-grace-period-length u1000000000000000000)
(define-constant max-dilution-bound u1000000000000000000)
(define-constant max-number-of-shares-and-loot u1000000000000000000)
(define-constant max-token-whitelist-count 400)
(define-constant max-token-guild-bank-count u200)

(define-constant guild (as-contract tx-sender))
(define-constant total (as-contract tx-sender)) ;; TODO some unused address
(define-constant escrow (as-contract tx-sender)) ;; TODO some unused address

(define-constant whitelist-flags (list false false false false true false false))
(define-constant guild-kick-flags (list false false false false false true false))

(define-data-var proposal-count uint u0)
(define-data-var total-shares uint u1) ;; must be created with one member
(define-data-var total-loot uint u0)

(define-data-var total-guild-bank-token-count uint u0)

(define-map user-token-balance
  ((user principal) (token principal))
  ((amount uint))
)

(define-map token-whitelist ((token principal)) ((approved bool)))
(define-data-var approved-tokens (list max-token-whitelist-count principal)
  (list deposit-token)
)

(begin
  (map-insert token-whitelist {token: deposit-token}
    {approved: true}
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
  (map-insert members ((member tx-sender))
    (
      (delegate-key tx-sender)
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
 (map-insert member-by-delegate-key ((delegate-key tx-sender))
    ((member tx-sender))
  )
)

(define-map proposals ((id uint))
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

(define-map proposal-queue ((index uint)) ((id uint)))
(define-data-var proposal-queue-length uint 0)

(define-private (unsafe-add-balance (sender principal) (receiver principal) (token principal) (amount uint))
  (begin
    (map-set user-token-balance ((user sender) (token token))
      (
        (amount
          (-
            (default-to u0 (get amount (map-get? user-token-balance ((user sender) (token token)))))
            amount
          )
        )
      )
    )

    (map-set user-token-balance ((user receiver) (token token))
      (
        (amount
          (+
            amount
            (default-to u0 (get amount (map-get? user-token-balance ((user receiver) (token token)))))
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
  (let ((id (+ u1 (var-get proposal-count))))
    (begin
      (map-insert proposals {id: id}
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
      (var-set proposal-count id)
      id
  )
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

(define-private (require-not-too-many-whitelisted-tokens (token principal))
  (unwrap-panic (if (< (len approved-tokens) max-token-whitelist-count) (some true) none))
)

(define-private (require-member-shares-or-loots
  (member (
    (delegate-key principal)
    (shares uint)
    (loot uint)
    (highest-index-yes-vote uint)
    (jailed uint)
  )))
  (unwrap-panic (if (or (> (get shares member) u0) (> (get loots member) u0)) (some true) none))
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
    (unsafe-add-balance tx-sender escrow (contract-of tribute-token) tribute-offered)
    (ok (add-proposal (some applicant) shares-requested loot-requested tribute-offered tribute-token payment-requested payment-token details (list)))
  )
)

(define-public (submit-whitelist-proposal (token-to-whitelist principal) (details (buff 256)))
 (begin
    (unwrap-err-panic (map-get? token-whitelist ((token (contract-of token-to-whitelist)))))
    (require-not-too-many-whitelisted-tokens (contract-of token-to-whitelist))
    (ok (add-proposal none u0 u0 u0 (contract-of token-to-whitelist) u0 none details whitelist-flags))
  )
)

(define-public (submit-guild-kick-proposal (member-to-kick principal) (details (buff 256)))
  (let ((member (unwrap-panic (map-get? members {member: member-to-kick}))))
    (begin
      (require-member-shares-or-loots member)
      (require-not-jailed (some member))
      (ok (add-proposal member-to-kick u0 u0 u0 none u0 none details guild-kick-flags))
    )
  )
)

(define-private (get-by-index (flag bool) (state (tuple (current-index uint) (requested-index uint) (result (optional bool)))))
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
    (fold get-by-index list-of-flags {current-index: u0, requested-index: index, result: none})
  )
)

(define-private (set-by-index (flag bool) (state (tuple (current-index uint) (requested-index uint) (result (list 6 bool)))))
  (tuple
    (current-index (+ (get current-index state) u1))
    (requested-index (get requested-index state))
    (result
      (if (is-eq (get current-index state) (get requested-index state))
        (append (get result state) true)
        (append (get result state) flag)
      )
    )
  )
)

(define-private (set-flag (index uint) (list-of-flags (list 6 bool)))
    (fold (set-by-index index) list-of-flags {current-index: u0, requested-index: index, result: (list)})
)

(define-private (require-not-true (index uint) (flags (list 6 bool)))
  (unwrap-panic (match (get-flag index flags)
                      flag (if flag none (some true))
                      (some true)
                    )
  )
)

(define-private (require-not-jailed (optional-member (optional principal)))
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

(define-private (update-proposal (proposal-id uint)
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
  )) (starting-period uint) (sponsor principal))

  (map-set proposals {id: proposal-index}
        (
          (applicant (get applicant proposal))
          (proposer (get proposer proposal))
          (sponsor (some sponsor))
          (shares-requested (get shares-requested proposal))
          (loot-requested (get loot-requested proposal))
          (tribute-offered (get tribute-offered proposal))
          (tribute-token (get tribute-token proposal))
          (payment-requested (get payment-requested proposal))
          (payment-token (get payment-token proposal))
          (starting-period starting-period)
          (yes-votes u0)
          (no-votes u0)
          (flags (set-flag u0 (get flags proposal)))
          (details (get details proposal))
          (max-total-shares-and-loot-at-yes-votes u0)
        )
      )
)

(define-private (get-current-period)
  (/ (- (get-time) summoning-time) period-duration)
)

(define-private (get-starting-period)
  (let
    (
      (last-period
        (let ((length (var-get proposal-queue-length)))
          (if (is-eq length u0)
            u0
            (get starting-period (map-get proposals {id: (get-id-of-queued-proposal (- length u1))})))))
      (current-period (get-current-period)))
    (+ u1 (if (> last-period current-period) last-period current-period))
  )
)

(define-public (sponsor-proposal (proposal-index uint))
  (begin
    (unwrap-panic (contract-call? deposit-token transfer-from? tx-sender escrow proposal-deposit))
    (unsafe-add-balance tx-sender escrow deposit-token proposal-deposit)
    (let ((proposal (unwrap-panic (map-get? proposals ((index proposal-index ))))))
      (begin
        (require-not-true u0 (get flags proposal))
        (require-not-true u3 (get flags proposal))
        (require-not-jailed (get applicant proposal))
        (require-not-too-many-guild-tokens (get tribute-offered proposal) (get tribute-token proposal))

        (if (get-flag u4 (get flags proposal))
          (let ((token-to-whitelist (get tribute-token proposal)))
            (begin
              (unwrap-panic (if (match (get approved (map-get? token-whitelist {token: token-to-whitelist})) approved approved true) (some true) none))
              (unwrap-panic (map-get? proposed-to-whitelist {token: token-to-whitelist}))
              (unwrap-panic (if (map-insert proposed-to-whitelist {token: token-to-whitelist} {proposed: true}) (some true) none))
            )
          )
          (if (get-flag u4 (get flags proposal))
            (let ((member  (get applicant proposal)))
              (begin
                (require-not-kicked member)
                (map-insert proposed-to-kick {member: member} {proposed: true})
              )
            )
            true
          )
        )

        (update-proposal proposal-index proposal (get-starting-period) (get member (map-get? member-by-delegate-key {delegate-key tx-sender})))
        (map-insert proposal-queue {index: proposal-index} {id: //TODO })
        (ok true)
      )
    )
  )
)

(define-private (submit-yes-vote (member principal) (proposal (tuple
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
  )) (proposal-index uint))
  (ok true)
)

(define-private (submit-no-vote (member principal) (proposal (tuple
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
  )) (proposal-index uint))
  (ok true)
)


(define-public (submit-vote (proposal-index uint) (vote bool))
  (let (
      (proposal (unwrap-panic (map-get? proposals {index: proposal-index})))
      (member (unwrap-panic (get member (map-get? member-by-delegate-key {delegate-key: tx-sender}))))
    )
    (begin
      (if (is-eq vote true)
        (submit-yes-vote member proposal proposal-index)
        (submit-no-vote member proposal proposal-index)
      )
      (ok true)
    )
  )
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

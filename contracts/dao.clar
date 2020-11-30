
(use-trait token-trait .dao-token-trait.token-trait)
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
(define-constant max-token-whitelist-count u400)
(define-constant max-token-guild-bank-count u200)

(define-constant guild (as-contract tx-sender))
(define-constant total (as-contract tx-sender)) ;; TODO some unused address
(define-constant escrow (as-contract tx-sender)) ;; TODO some unused address

(define-constant whitelist-flags (list false false false false true false))
(define-constant guild-kick-flags (list false false false false false true))

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

(define-map votes-by-member ((proposal-index uint) (member principal))
  (
    (vote (optional bool))
  )
)

(define-map proposal-queue ((index uint)) ((id uint)))
(define-data-var proposal-queue-length uint u0)

(define-private (unsafe-add-to-balance (user principal) (token principal) (amount uint))
  (begin
    (map-set user-token-balance {user: user, token: token}
      {amount: (+
            (default-to u0 (get amount (map-get? user-token-balance {user: user, token: token})))
            amount)}
    )

    (map-set user-token-balance {user: total, token: token}
      {amount: (+
            (default-to u0 (get amount (map-get? user-token-balance {user: total, token: token})))
            amount)}
    )
  )
)

(define-private (unsafe-substract-from-balance (user principal) (token principal) (amount uint))
  (begin
    (map-set user-token-balance {user: user, token: token}
      {amount: (-
            (default-to u0 (get amount (map-get? user-token-balance {user: user, token: token})))
            amount)}
    )

    (map-set user-token-balance {user: total, token: token}
      {amount: (-
            (default-to u0 (get amount (map-get? user-token-balance {user: total, token: token})))
            amount)}
    )
  )
)

(define-private (unsafe-internal-transfer (sender principal) (receiver principal) (token principal) (amount uint))
  (begin
    (unsafe-substract-from-balance sender token amount)
    (unsafe-add-to-balance receiver token amount)
  )
)

(define-private (return-deposit (sponsor principal))
  (begin
    (unsafe-internal-transfer escrow tx-sender deposit-token processing-reward)
    (unsafe-internal-transfer escrow sponsor deposit-token (- proposal-deposit processing-reward))
  )
)

(define-private (inc-proposal-count)
  (var-set proposal-count (+ u1 (var-get proposal-count)))
)

(define-private (inc-proposal-queue-length)
  (let ((new-length (+ u1 (var-get proposal-queue-length))))
    (begin
      (var-set proposal-queue-length new-length)
      new-length
    )
  )
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
)

(define-private (require-true (value bool))
  (unwrap-panic (if value (some true) none))
)

(define-private (require-no-vote (value (optional (tuple (vote (optional bool))))))
  (unwrap-panic
    (match value
      some-value none
      (some true)
    )
  )
)

(define-private (require-in-voting-period (starting-period uint))
  (let ((current-period (get-current-period)))
    (require-true (and (>= current-period starting-period) (< current-period (+ starting-period voting-period-length))))
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
  (unwrap-panic (if (< (len (var-get approved-tokens)) max-token-whitelist-count) (some true) none))
)

(define-private (require-member-shares-or-loot
  (member (tuple
    (delegate-key principal)
    (shares uint)
    (loot uint)
    (highest-index-yes-vote uint)
    (jailed uint)
  )))
  (unwrap-panic (if (or (> (get shares member) u0) (> (get loot member) u0)) (some true) none))
)


(define-read-only (id-queued-proposal (proposal-index uint))
  (unwrap-panic (get id (map-get? proposal-queue {index: proposal-index})))
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
    (unsafe-add-to-balance escrow (contract-of tribute-token) tribute-offered)
    (ok (add-proposal (some applicant) shares-requested loot-requested tribute-offered tribute-token payment-requested payment-token details (list)))
  )
)

(define-public (submit-whitelist-proposal (token-to-whitelist <token-trait>) (details (buff 256)))
 (begin
    (unwrap-panic (match (get approved (map-get? token-whitelist ((token (contract-of token-to-whitelist))))) approved none (some true)))
    (require-not-too-many-whitelisted-tokens (contract-of token-to-whitelist))
    (ok (add-proposal none u0 u0
            u0 token-to-whitelist
            u0 token-to-whitelist
            details whitelist-flags))
  )
)

(define-public (submit-guild-kick-proposal (member-to-kick principal) (details (buff 256)))
  (let ((member (unwrap-panic (map-get? members {member: member-to-kick}))))
    (begin
      (require-member-shares-or-loot member)
      (require-not-jailed-member member)
      (ok (add-proposal (some member-to-kick) u0 u0 u0 .dao-token u0 .dao-token details guild-kick-flags))
    )
  )
)


(define-public (sponsor-proposal (proposal-id uint))
  (begin
    (unwrap-panic (contract-call? .dao-token transfer-from? tx-sender escrow proposal-deposit))
    (unsafe-add-to-balance escrow deposit-token proposal-deposit)
    (let ((proposal (unwrap-panic (map-get? proposals {id: proposal-id}))))
      (begin
        (require-false u0 (get flags proposal))
        (require-false u3 (get flags proposal))
        (require-not-jailed (get applicant proposal))
        (require-not-too-many-guild-tokens (get tribute-offered proposal) (get tribute-token proposal))

        (if (get-flag u4 (get flags proposal))
          (let ((token-to-whitelist (get tribute-token proposal)))
            (begin
              (unwrap-panic (if (match (get approved (map-get? token-whitelist {token: token-to-whitelist}))
                                  approved approved
                                  true)
                              (some true)
                              none))
              (unwrap-panic (map-get? proposed-to-whitelist {token: token-to-whitelist}))
              (unwrap-panic (if (map-insert proposed-to-whitelist {token: token-to-whitelist} {proposed: true}) (some true) none))
              true
            )
          )
          (if (get-flag u4 (get flags proposal))
            (let ((member (unwrap-panic (get applicant proposal))))
              (begin
                (require-not-proposed-to-kick member)
                (map-insert proposed-to-kick {member: member} {proposed: true})
              )
            )
           true
          )
        )

        (update-proposal-for-sponsoring proposal-id proposal (get-starting-period) (unwrap-panic (get member (map-get? member-by-delegate-key {delegate-key: tx-sender}))))
        (let ((proposal-index (inc-proposal-queue-length)))
          (require-true (map-insert proposal-queue {index: proposal-index} {id: proposal-id }))
        )
        (ok true)
      )
    )
  )
)


(define-public (process-proposal (proposal-index uint))
  (begin
    (validate-proposal-for-processing proposal-index)
    (let ((proposal-id (id-queued-proposal proposal-index)))
      (let ((proposal (unwrap-panic (get-proposal-by-index? proposal-index))))
        (begin
          (require-true (and (not (get-flag u4 (get flags proposal))) (not (get-flag u5 (get flags proposal)))))

          (update-proposal-for-processing proposal-id proposal)
          (if (and (did-pass proposal)
                  (<= (+ (var-get total-shares) (var-get total-loot)
                          (get shares-requested proposal)
                          (get loot-requested proposal)
                      )
                      max-number-of-shares-and-loot)
                  ;; todo: check payment requested
                  ;; todo: non-zero balance guide accounts
            )
            ;; proposal did pass
            (begin
                (update-proposal-for-passed-vote proposal-id proposal)

                (match (get applicant proposal)
                  applicant (match (map-get? members {member: applicant})
                    member-data (update-member-shares-and-loot applicant member-data (get shares-requested proposal) (get loot-requested proposal))
                    (begin
                      ;; if the applicant address is already taken by a member's delegateKey, reset it to their member address
                      (match (get member (map-get? member-by-delegate-key {delegate-key: applicant}))
                        member-to-override (begin
                            (map-set member-by-delegate-key {delegate-key: member-to-override} {member: member-to-override})
                            (update-member-delegate-key member-to-override))
                        true
                      )
                      (map-set members {member: applicant}
                        {
                          delegate-key: applicant,
                          shares: (get shares-requested proposal),
                          loot: (get loot-requested proposal),
                          highest-index-yes-vote: u0,
                          jailed: u0
                        })
                      (map-set member-by-delegate-key {delegate-key: applicant} {member: applicant})
                    ))
                  true
                )
                (var-set total-shares (+ (var-get total-shares) (get shares-requested proposal)))
                (var-set total-loot (+ (var-get total-loot) (get loot-requested proposal)))
                ;; if the proposal tribute is the first tokens of its kind to make it into the guild bank, increment total guild bank tokens
                (update-total-guild-bank-tokens-for-tribute (get payment-token proposal) (get payment-requested proposal))
                (unsafe-internal-transfer escrow guild (get tribute-token proposal) (get tribute-offered proposal))
                (unsafe-internal-transfer guild (unwrap-panic (get applicant proposal)) (get payment-token proposal) (get payment-requested proposal))
                ;; if the proposal spends 100% of guild bank balance for a token, decrement total guild bank tokens
                (update-total-guild-bank-tokens-for-payment (get payment-token proposal) (get payment-requested proposal))
            )
            ;; proposal did not pass
            (unsafe-internal-transfer escrow (get proposer proposal) (get tribute-token proposal) (get tribute-offered proposal))
          )
          (return-deposit (unwrap-panic (get sponsor proposal)))
          (ok true)
        )
      )
    )
  )
)

;;
;; Private functions
;; not changing the state
;;
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
  (unwrap-panic (get-flag? index list-of-flags))
)

(define-private (get-flag? (index uint) (list-of-flags (list 6 bool)))
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
        (unwrap-panic (as-max-len? (append (get result state) true) u6))
        (unwrap-panic (as-max-len? (append (get result state) flag) u6))
      )
    )
  )
)

(define-private (set-flag (index uint) (list-of-flags (list 6 bool)))
  (get result (fold set-by-index list-of-flags {current-index: u0, requested-index: index, result: (list)}))
)

(define-private (did-pass
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
  )))

  (and
    (> (get yes-votes proposal) (get no-votes proposal))
    (>= (* (+ (var-get total-shares) (var-get total-loot)) dilution-bound)
      (get max-total-shares-and-loot-at-yes-votes proposal))
    (is-eq u0 (unwrap-panic (get jailed (map-get? members {member: (unwrap-panic (get applicant proposal))})))))
)

(define-private (require-false (index uint) (flags (list 6 bool)))
  (unwrap-panic (match (get-flag? index flags)
                      flag (if flag none (some true))
                      (some true)
                    )
  )
)

(define-private (require-not-proposed-to-kick (member principal))
    (match (get proposed (map-get? proposed-to-kick {member: member}))
    proposed (unwrap-panic (if proposed (some true) none))
    true
  )
)

(define-private (require-not-jailed (optional-member (optional principal)))
  (match optional-member
    member (match (map-get? members ((member member)))
              member-data (require-not-jailed-member member-data)
              true)
    true
  )
)

(define-private (require-not-jailed-member (member (tuple
        (delegate-key principal)
        (shares uint)
        (loot uint)
        (highest-index-yes-vote uint)
        (jailed uint)
    )))
  (unwrap-panic (if (is-eq (get jailed member) u0) (some true) none))
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
            (unwrap-panic (get starting-period (get-proposal-by-index? (- length u1)))))))
      (current-period (get-current-period)))
    (+ u1 (if (> last-period current-period) last-period current-period))
  )
)

(define-read-only (get-proposal-by-index? (proposal-index uint))
  (map-get? proposals {id: (id-queued-proposal proposal-index)})
)

(define-private (validate-proposal-for-processing (proposal-index uint))
  (let ((proposal (unwrap-panic (get-proposal-by-index? (id-queued-proposal proposal-index)))))
    (begin
      (asserts! (< proposal-index  (var-get proposal-queue-length)) (err "proposal does not exist"))
      (asserts! (>= (get-current-period) (get starting-period proposal)) (err "proposal not ready to be processed"))
      (asserts! (not (get-flag u1 (get flags proposal))) (err "proposal has already been processed"))
      (asserts! (or (is-eq proposal-index u0) (get-flag u1 (get flags (unwrap-panic (get-proposal-by-index? (- proposal-index u1)))))) (err "previous proposal must be processed")))
      (ok true)
  )
)

;;
;; private functions changing the state
;;
(define-private (update-proposal-for-sponsoring (proposal-id uint)
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
  ))
  (starting-period uint) (sponsor principal))

  (map-set proposals {id: proposal-id}
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



(define-private (update-proposal-for-vote
    (member (tuple
        (delegate-key principal)
        (shares uint)
        (loot uint)
        (highest-index-yes-vote uint)
        (jailed uint)
    ))
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
      ))
    (proposal-index uint) (vote bool)
  )
  (let ((shares (get shares member))
      (total-tokens (+ (var-get total-shares) (var-get total-loot)))
      (max-total (get max-total-shares-and-loot-at-yes-votes proposal))
    )
    (map-set proposals {id: (id-queued-proposal proposal-index)}
        (
          (applicant (get applicant proposal))
          (proposer (get proposer proposal))
          (sponsor (get sponsor proposal))
          (shares-requested (get shares-requested proposal))
          (loot-requested (get loot-requested proposal))
          (tribute-offered (get tribute-offered proposal))
          (tribute-token (get tribute-token proposal))
          (payment-requested (get payment-requested proposal))
          (payment-token (get payment-token proposal))
          (starting-period (get starting-period proposal))
          (yes-votes (if vote (+ (get yes-votes proposal) shares) (get yes-votes proposal)))
          (no-votes (if vote (get no-votes proposal) (+ (get no-votes proposal) shares)))
          (flags (get flags proposal))
          (details (get details proposal))
          (max-total-shares-and-loot-at-yes-votes
            (if vote
              (if (> total-tokens max-total) total-tokens max-total)
              max-total
            )
          )
        )
      )
  )
)

(define-private (update-member (member principal) (member-data (tuple (delegate-key principal) (shares uint) (loot uint) (highest-index-yes-vote uint) (jailed uint))) (index uint))
  (map-set members {member: member}
    {
      delegate-key: (get delegate-key member-data),
      shares: (get shares member-data),
      loot: (get loot member-data),
      highest-index-yes-vote: index,
      jailed: (get jailed member-data)}
  )
)

(define-private (update-member-shares-and-loot (member principal) (member-data (tuple (delegate-key principal) (shares uint) (loot uint) (highest-index-yes-vote uint) (jailed uint))) (shares uint) (loot uint))
  (map-set members {member: member}
    {
      delegate-key: (get delegate-key member-data),
      shares: (+ shares (get shares member-data)),
      loot: (+ loot (get loot member-data)),
      highest-index-yes-vote: (get highest-index-yes-vote member-data),
      jailed: (get jailed member-data)}
  )
)

(define-private (update-member-delegate-key (member principal))
  (match (map-get? members {member: member})
    member-data (map-set members {member: member}
      {
        delegate-key: member,
        shares: (get shares member-data),
        loot: (get loot member-data),
        highest-index-yes-vote: (get highest-index-yes-vote member-data),
        jailed: (get jailed member-data)})
    true
  )
)


(define-private (update-proposal-for-processing (proposal-id uint)
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
  )))

  (map-set proposals {id: proposal-id}
        (
          (applicant (get applicant proposal))
          (proposer (get proposer proposal))
          (sponsor (get sponsor proposal))
          (shares-requested (get shares-requested proposal))
          (loot-requested (get loot-requested proposal))
          (tribute-offered (get tribute-offered proposal))
          (tribute-token (get tribute-token proposal))
          (payment-requested (get payment-requested proposal))
          (payment-token (get payment-token proposal))
          (starting-period (get starting-period proposal))
          (yes-votes (get yes-votes proposal))
          (no-votes (get no-votes proposal))
          (flags (set-flag u2 (get flags proposal))) ;; set passed to true
          (details (get details proposal))
          (max-total-shares-and-loot-at-yes-votes (get max-total-shares-and-loot-at-yes-votes proposal))
        )
      )
)

(define-private (update-proposal-for-passed-vote (proposal-id uint)
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
  )))

  (map-set proposals {id: proposal-id}
        (
          (applicant (get applicant proposal))
          (proposer (get proposer proposal))
          (sponsor (get sponsor proposal))
          (shares-requested (get shares-requested proposal))
          (loot-requested (get loot-requested proposal))
          (tribute-offered (get tribute-offered proposal))
          (tribute-token (get tribute-token proposal))
          (payment-requested (get payment-requested proposal))
          (payment-token (get payment-token proposal))
          (starting-period (get starting-period proposal))
          (yes-votes (get yes-votes proposal))
          (no-votes (get no-votes proposal))
          (flags (set-flag u1 (get flags proposal))) ;; set processes to true
          (details (get details proposal))
          (max-total-shares-and-loot-at-yes-votes (get max-total-shares-and-loot-at-yes-votes proposal))
        )
      )
)

(define-private (update-total-guild-bank-tokens-for-tribute (tribute-token principal) (amount uint))
  (match (get amount (map-get? user-token-balance {user: guild, token: tribute-token}))
    balance (if (and
                  (is-eq balance u0)
                  (> amount u0))
                (var-set total-guild-bank-token-count (+ (var-get total-guild-bank-token-count) u1))
                true
            )
    true
  )
)

(define-private (update-total-guild-bank-tokens-for-payment  (payment-token principal) (amount uint))
  (match (get amount (map-get? user-token-balance {user: guild, token: payment-token}))
      balance (if (and
                    (is-eq balance u0)
                    (> amount u0))
                  (var-set total-guild-bank-token-count (- (var-get total-guild-bank-token-count) u1))
                  true
              )
      true
    )
)

;;
;; members can submit a vote to proposal
;; If vote is none it counts as abstention, i.e. are only registered on chain and don't have an impact on the result
;;
(define-public (submit-vote (proposal-index uint) (vote (optional bool)))
  (let (
      (proposal (unwrap-panic (get-proposal-by-index? proposal-index)))
      (member (unwrap-panic (get member (map-get? member-by-delegate-key {delegate-key: tx-sender}))))
    )
    (let (
        (starting-period (get starting-period proposal))
      )
      (begin
        (require-no-vote (map-get? votes-by-member {proposal-index: proposal-index, member: member}))
        (require-in-voting-period starting-period)
        (require-true (map-insert votes-by-member {proposal-index: proposal-index, member: member} {vote: vote}))
        (match vote
          yes-no-vote (let ((member-data (unwrap-panic (map-get? members {member: member}))))
            (begin
              (if yes-no-vote (let ((index (get highest-index-yes-vote member-data)))
                                    (if (> proposal-index index)
                                      (update-member member member-data index)
                                      true
                                    ))

                              true)
              (update-proposal-for-vote member-data proposal proposal-index yes-no-vote)
            ))
          true ;; abstention
        )
        (ok true)
      )
    )
  )
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

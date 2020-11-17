(define-trait token-trait
    ((transfer-from? (principal principal uint) (response uint uint)))
)

(define-private (update-member (member principal) (member-data (tuple (delegate-key principal) (shares uint) (loot uint) (highest-index-yes-vote uint) (jailed uint))) (index uint))
 (ok true)
)

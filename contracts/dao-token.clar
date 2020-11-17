(impl-trait .dao-token-trait.token-trait)

(define-fungible-token dao-token)

(define-public (transfer-from? (sender principal) (recipient principal) (amount uint))
  (ok amount)
)

(define-trait token-trait
  (
    (transfer-to? (uint principal) (response bool uint))
    (balance-of (principal) (response uint uint))
  )
)

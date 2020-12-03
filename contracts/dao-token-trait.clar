(define-trait token-trait
  (
    (transfer? (uint principal principal) (response bool uint))
    (balance-of (principal) (response uint uint))
  )
)

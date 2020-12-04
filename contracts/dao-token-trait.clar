(define-trait token-trait
  (
    (transfer? (uint principal principal) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

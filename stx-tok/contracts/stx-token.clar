;; STX Token Optimization - Improved Version
;; Filename: token-optimization-v2.clar

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_RECIPIENT (err u102))
(define-constant ERR_TRANSFER_FAILED (err u103))

;; Define data vars
(define-data-var token-name (string-ascii 32) "OptimizedSTX")
(define-data-var token-symbol (string-ascii 10) "OSTX")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var total-supply uint u0)

;; Define data maps
(define-map balances principal uint)
(define-map allowances { owner: principal, spender: principal } uint)

;; Define fungible token trait
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Define read-only functions
(define-read-only (get-name)
  (ok (var-get token-name)))

(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

(define-read-only (get-decimals)
  (ok u6))

(define-read-only (get-balance (account principal))
  (ok (default-to u0 (map-get? balances account))))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

;; Define public functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_RECIPIENT)
    (try! (ft-transfer? amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (try! (ft-mint? amount recipient))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)))

;; Improved batch transfer function with error handling and events
(define-public (batch-transfer (transfers (list 200 { amount: uint, recipient: principal, memo: (optional (buff 34)) })))
  (let ((sender tx-sender))
    (asserts! (> (len transfers) u0) ERR_INVALID_RECIPIENT)
    (ok (fold process-transfer transfers true))))

;; Helper function for optimized batch transfers
(define-private (process-transfer (transfer { amount: uint, recipient: principal, memo: (optional (buff 34)) }) (previous-result bool))
  (if previous-result
    (match (transfer (get amount transfer) tx-sender (get recipient transfer) (get memo transfer))
      success (begin
        (print {event: "transfer", amount: (get amount transfer), sender: tx-sender, recipient: (get recipient transfer)})
        true)
      error false)
    false))

;; New feature: Time-locked transfers
(define-map time-locks { recipient: principal, unlock-height: uint } uint)

(define-public (create-time-lock (recipient principal) (amount uint) (unlock-height uint))
  (begin
    (asserts! (>= unlock-height block-height) ERR_INVALID_RECIPIENT)
    (try! (transfer amount tx-sender (as-contract tx-sender) none))
    (map-set time-locks { recipient: recipient, unlock-height: unlock-height } amount)
    (ok true)))

(define-public (release-time-lock (recipient principal) (unlock-height uint))
  (let ((locked-amount (default-to u0 (map-get? time-locks { recipient: recipient, unlock-height: unlock-height }))))
    (asserts! (>= block-height unlock-height) ERR_UNAUTHORIZED)
    (asserts! (> locked-amount u0) ERR_INSUFFICIENT_BALANCE)
    (try! (as-contract (transfer locked-amount tx-sender recipient none)))
    (map-delete time-locks { recipient: recipient, unlock-height: unlock-height })
    (ok true)))

;; New feature: Allowance and approved transfers
(define-public (set-allowance (spender principal) (amount uint))
  (begin
    (map-set allowances { owner: tx-sender, spender: spender } amount)
    (print {event: "allowance_set", owner: tx-sender, spender: spender, amount: amount})
    (ok true)))

(define-public (transfer-from (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (let ((current-allowance (default-to u0 (map-get? allowances { owner: sender, spender: tx-sender }))))
    (asserts! (>= current-allowance amount) ERR_INSUFFICIENT_BALANCE)
    (try! (transfer amount sender recipient memo))
    (map-set allowances { owner: sender, spender: tx-sender } (- current-allowance amount))
    (ok true)))

;; SIP-010 transfer function
(define-public (transfer-ft (amount uint) (sender principal) (recipient principal))
  (transfer amount sender recipient none))

;; SIP-010 mint function
(define-public (mint-ft (amount uint) (recipient principal))
  (mint amount recipient))
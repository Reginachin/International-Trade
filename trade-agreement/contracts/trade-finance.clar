;; Trade Finance Smart Contract
;; Implements Letter of Credit (LC) functionality with multi-party verification

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1))
(define-constant ERR-INVALID-TRADE-STATE (err u2))
(define-constant ERR-TRADE-ALREADY-EXISTS (err u3))
(define-constant ERR-TRADE-EXPIRED (err u4))
(define-constant ERR-INSUFFICIENT-TRADE-FUNDS (err u5))

;; Contract variables
(define-data-var trade-contract-administrator principal tx-sender)

;; Comprehensive trade information storage
(define-map letter-of-credit-details
    { letter-of-credit-id: uint }
    {
        importing-entity: principal,
        exporting-entity: principal,
        issuing-bank: principal,
        transaction-amount: uint,
        payment-currency: principal,
        expiration-date: uint,
        trade-status: (string-ascii 20),
        shipping-documents-hash: (buff 32),
        trade-active-status: bool
    }
)

;; Document verification tracking system
(define-map shipping-document-verifications
    { letter-of-credit-id: uint, document-verifier: principal }
    { verification-status: bool }
)

;; Trade status constants
(define-constant TRADE-STATUS-INITIATED "INITIATED")
(define-constant TRADE-STATUS-DOCUMENTS-UPLOADED "DOCS_UPLOADED")
(define-constant TRADE-STATUS-DOCUMENTS-VERIFIED "VERIFIED")
(define-constant TRADE-STATUS-TRANSACTION-COMPLETED "COMPLETED")
(define-constant TRADE-STATUS-TRANSACTION-CANCELLED "CANCELLED")

;; Public functions

;; Initialize new letter of credit
(define-public (create-letter-of-credit 
                (letter-of-credit-id uint) 
                (exporting-entity principal)
                (issuing-bank principal)
                (transaction-amount uint)
                (payment-currency principal)
                (expiration-date uint))
    (let ((existing-letter-of-credit (get-letter-of-credit-details letter-of-credit-id)))
        (asserts! (is-eq tx-sender (var-get trade-contract-administrator)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-none existing-letter-of-credit) ERR-TRADE-ALREADY-EXISTS)
        (asserts! (> expiration-date block-height) ERR-TRADE-EXPIRED)
        
        (ok (map-set letter-of-credit-details
            { letter-of-credit-id: letter-of-credit-id }
            {
                importing-entity: tx-sender,
                exporting-entity: exporting-entity,
                issuing-bank: issuing-bank,
                transaction-amount: transaction-amount,
                payment-currency: payment-currency,
                expiration-date: expiration-date,
                trade-status: TRADE-STATUS-INITIATED,
                shipping-documents-hash: 0x00,
                trade-active-status: true
            }
        ))
    )
)

;; Upload shipping documents
(define-public (submit-shipping-documents (letter-of-credit-id uint) (shipping-documents-hash (buff 32)))
    (let ((letter-of-credit (unwrap! (get-letter-of-credit-details letter-of-credit-id) ERR-INVALID-TRADE-STATE)))
        (asserts! (is-eq tx-sender (get exporting-entity letter-of-credit)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get trade-status letter-of-credit) TRADE-STATUS-INITIATED) ERR-INVALID-TRADE-STATE)
        (asserts! (< block-height (get expiration-date letter-of-credit)) ERR-TRADE-EXPIRED)
        
        (ok (map-set letter-of-credit-details
            { letter-of-credit-id: letter-of-credit-id }
            (merge letter-of-credit {
                trade-status: TRADE-STATUS-DOCUMENTS-UPLOADED,
                shipping-documents-hash: shipping-documents-hash
            })
        ))
    )
)

;; Verify shipping documents
(define-public (verify-shipping-documents (letter-of-credit-id uint))
    (let ((letter-of-credit (unwrap! (get-letter-of-credit-details letter-of-credit-id) ERR-INVALID-TRADE-STATE)))
        (asserts! (is-eq tx-sender (get issuing-bank letter-of-credit)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get trade-status letter-of-credit) TRADE-STATUS-DOCUMENTS-UPLOADED) ERR-INVALID-TRADE-STATE)
        (asserts! (< block-height (get expiration-date letter-of-credit)) ERR-TRADE-EXPIRED)
        
        (map-set shipping-document-verifications
            { letter-of-credit-id: letter-of-credit-id, document-verifier: tx-sender }
            { verification-status: true }
        )
        
        (ok (map-set letter-of-credit-details
            { letter-of-credit-id: letter-of-credit-id }
            (merge letter-of-credit { trade-status: TRADE-STATUS-DOCUMENTS-VERIFIED })
        ))
    )
)

;; Process payment for verified documents
(define-public (process-trade-payment (letter-of-credit-id uint))
    (let ((letter-of-credit (unwrap! (get-letter-of-credit-details letter-of-credit-id) ERR-INVALID-TRADE-STATE)))
        (asserts! (is-eq tx-sender (get issuing-bank letter-of-credit)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (is-eq (get trade-status letter-of-credit) TRADE-STATUS-DOCUMENTS-VERIFIED) ERR-INVALID-TRADE-STATE)
        (asserts! (< block-height (get expiration-date letter-of-credit)) ERR-TRADE-EXPIRED)
        
        ;; Transfer tokens using SIP-010 trait
        (let ((token-contract (contract-of (get payment-currency letter-of-credit))))
            (try! (contract-call? token-contract transfer
                (get transaction-amount letter-of-credit)
                (get importing-entity letter-of-credit)
                (get exporting-entity letter-of-credit)
                none
            ))
        )
        
        (ok (map-set letter-of-credit-details
            { letter-of-credit-id: letter-of-credit-id }
            (merge letter-of-credit { 
                trade-status: TRADE-STATUS-TRANSACTION-COMPLETED,
                trade-active-status: false 
            })
        ))
    )
)

;; Cancel letter of credit
(define-public (cancel-letter-of-credit (letter-of-credit-id uint))
    (let ((letter-of-credit (unwrap! (get-letter-of-credit-details letter-of-credit-id) ERR-INVALID-TRADE-STATE)))
        (asserts! (or
            (is-eq tx-sender (get importing-entity letter-of-credit))
            (is-eq tx-sender (get issuing-bank letter-of-credit))
        ) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (not (is-eq (get trade-status letter-of-credit) TRADE-STATUS-TRANSACTION-COMPLETED)) ERR-INVALID-TRADE-STATE)
        
        (ok (map-set letter-of-credit-details
            { letter-of-credit-id: letter-of-credit-id }
            (merge letter-of-credit { 
                trade-status: TRADE-STATUS-TRANSACTION-CANCELLED,
                trade-active-status: false 
            })
        ))
    )
)

;; Read-only functions

;; Retrieve letter of credit details
(define-read-only (get-letter-of-credit-details (letter-of-credit-id uint))
    (map-get? letter-of-credit-details { letter-of-credit-id: letter-of-credit-id })
)

;; Check document verification status
(define-read-only (check-document-verification-status (letter-of-credit-id uint) (document-verifier principal))
    (default-to 
        { verification-status: false }
        (map-get? shipping-document-verifications 
            { letter-of-credit-id: letter-of-credit-id, document-verifier: document-verifier })
    )
)

;; Check if letter of credit is active
(define-read-only (is-letter-of-credit-active (letter-of-credit-id uint))
    (match (get-letter-of-credit-details letter-of-credit-id)
        letter-of-credit-data (get trade-active-status letter-of-credit-data)
        false
    )
)

;; Get letter of credit status
(define-read-only (get-letter-of-credit-status (letter-of-credit-id uint))
    (match (get-letter-of-credit-details letter-of-credit-id)
        letter-of-credit-data (some (get trade-status letter-of-credit-data))
        none
    )
)
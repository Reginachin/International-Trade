# Trade Finance Smart Contract

## Overview

The Trade Finance Smart Contract facilitates secure and efficient international trade transactions by implementing a Letter of Credit system. It allows for the creation, management, and execution of trade agreements between importing entities, exporting entities, and issuing banks.

## Features

- Creation of Letters of Credit
- Submission and verification of shipping documents
- Secure payment processing using SIP-010 compliant tokens
- Multi-party verification system
- Trade status tracking
- Cancellation of Letters of Credit

## Prerequisites

- Clarity language knowledge
- Stacks blockchain environment
- SIP-010 compliant token contract for payment processing

## Contract Structure

The contract consists of several main components:

1. Data storage:
   - `letter-of-credit-details`: Stores comprehensive trade information
   - `shipping-document-verifications`: Tracks document verification status

2. Public functions:
   - `create-letter-of-credit`: Initializes a new Letter of Credit
   - `submit-shipping-documents`: Allows exporters to submit shipping documents
   - `verify-shipping-documents`: Enables issuing banks to verify submitted documents
   - `process-trade-payment`: Executes the payment for verified trades
   - `cancel-letter-of-credit`: Cancels an active Letter of Credit

3. Read-only functions:
   - `get-letter-of-credit-details`: Retrieves details of a specific Letter of Credit
   - `check-document-verification-status`: Checks the verification status of submitted documents
   - `is-letter-of-credit-active`: Checks if a Letter of Credit is still active
   - `get-letter-of-credit-status`: Retrieves the current status of a Letter of Credit

## Usage

### Creating a Letter of Credit

To create a new Letter of Credit:

```clarity
(contract-call? .trade-finance-contract create-letter-of-credit
    u1  ;; letter-of-credit-id
    'SPEXPORTER...  ;; exporting-entity
    'SPBANK...  ;; issuing-bank
    u1000000  ;; transaction-amount
    'SP...  ;; payment-currency (SIP-010 token contract)
    u100000  ;; expiration-date (block height)
)
```

### Submitting Shipping Documents

For an exporter to submit shipping documents:

```clarity
(contract-call? .trade-finance-contract submit-shipping-documents
    u1  ;; letter-of-credit-id
    0x...  ;; shipping-documents-hash (32-byte buffer)
)
```

### Verifying Shipping Documents

For an issuing bank to verify submitted documents:

```clarity
(contract-call? .trade-finance-contract verify-shipping-documents
    u1  ;; letter-of-credit-id
)
```

### Processing Payment

For an issuing bank to process the payment after document verification:

```clarity
(contract-call? .trade-finance-contract process-trade-payment
    u1  ;; letter-of-credit-id
)
```

### Cancelling a Letter of Credit

To cancel an active Letter of Credit:

```clarity
(contract-call? .trade-finance-contract cancel-letter-of-credit
    u1  ;; letter-of-credit-id
)
```

## Error Handling

The contract includes several error codes for different scenarios:

- `ERR-UNAUTHORIZED-ACCESS`: Thrown when an unauthorized principal attempts to perform an action
- `ERR-INVALID-TRADE-STATE`: Thrown when an action is attempted in an invalid trade state
- `ERR-TRADE-ALREADY-EXISTS`: Thrown when attempting to create a Letter of Credit with an existing ID
- `ERR-TRADE-EXPIRED`: Thrown when attempting to perform actions on an expired Letter of Credit
- `ERR-INSUFFICIENT-TRADE-FUNDS`: Thrown when there are insufficient funds for a trade transaction

## Security Considerations

- Only authorized principals can perform specific actions
- The contract uses a multi-party verification system to ensure the integrity of the trade process
- Expiration dates are enforced to prevent actions on expired Letters of Credit
- The contract relies on SIP-010 compliant tokens for secure payment processing
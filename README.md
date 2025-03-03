# PeerFund
A decentralized platform for peer funding built on the Stacks blockchain.

## Features
- Create funding campaigns
- Contribute STX to campaigns
- Withdraw funds once campaign goal is reached
- View campaign details and progress
- Refund contributions if campaign fails

## Setup and Installation
1. Clone the repository
2. Install Clarinet
3. Run `clarinet check` to verify contracts
4. Run `clarinet test` to run test suite

## Usage Examples
```clarity
;; Create a new campaign
(contract-call? .peer-fund create-campaign 
  "My Campaign" 
  "Description" 
  u1000000 
  u864000)

;; Contribute to a campaign
(contract-call? .peer-fund contribute u1 u100000)

;; Check campaign status
(contract-call? .peer-fund get-campaign-info u1)

;; Withdraw funds (campaign owner)
(contract-call? .peer-fund withdraw-funds u1)

;; Get refund (contributor)
(contract-call? .peer-fund get-refund u1)
```

## Dependencies
- Clarity language
- Clarinet for testing and deployment

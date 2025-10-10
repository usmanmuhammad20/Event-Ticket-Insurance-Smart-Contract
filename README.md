# 🎟️ Event Ticket Insurance Smart Contract

## 📋 Overview

A Clarity smart contract that provides **insurance protection** for event tickets. Get your money back if an event gets canceled! 🔄💰

## ✨ Features

- 🎪 **Event Creation**: Organizers can create events with ticket pricing and insurance fees
- 🎫 **Ticket Purchase**: Buy tickets with optional insurance coverage
- 🔮 **Oracle Integration**: Trusted oracles verify event status (active, completed, canceled)
- 💸 **Automatic Refunds**: Get full refunds if insured events are canceled
- 🏦 **Revenue Withdrawal**: Organizers can withdraw proceeds after events

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd Event-Ticket-Insurance-Smart-Contract
clarinet console
```

## 📖 Usage Guide

### 🎭 For Event Organizers

#### Create an Event
```clarity
(contract-call? .Event-Ticket-Insurance create-event 
  "Rock Concert 2024" 
  u1000000          ;; event date (block height)
  u50000000         ;; ticket price (50 STX)
  u5000000          ;; insurance fee (5 STX)
  u100)             ;; total tickets
```

#### Withdraw Revenue
```clarity
(contract-call? .Event-Ticket-Insurance withdraw-proceeds u1)
```

### 🎟️ For Ticket Buyers

#### Buy Ticket with Insurance
```clarity
(contract-call? .Event-Ticket-Insurance buy-ticket u1 true)
```

#### Buy Ticket without Insurance
```clarity
(contract-call? .Event-Ticket-Insurance buy-ticket u1 false)
```

#### Claim Refund (if event canceled)
```clarity
(contract-call? .Event-Ticket-Insurance claim-refund u1)
```

### 🔮 For Oracles

#### Update Event Status
```clarity
(contract-call? .Event-Ticket-Insurance update-event-status u1 "canceled")
```

## 🏗️ Contract Architecture

### Data Structures

#### Events Map
- `organizer`: Event creator
- `name`: Event name (max 100 chars)
- `date`: Event date (block height)
- `ticket-price`: Price per ticket
- `insurance-fee`: Insurance cost
- `total-tickets`: Maximum tickets
- `sold-tickets`: Tickets sold
- `status`: "active", "completed", or "canceled"

#### Tickets Map
- `event-id`: Associated event
- `buyer`: Ticket owner
- `purchase-block`: Purchase time
- `has-insurance`: Insurance coverage
- `refund-claimed`: Refund status

## 🛡️ Security Features

- ✅ **Access Control**: Only authorized oracles can update event status
- ✅ **Owner Validation**: Only event organizers can withdraw revenue
- ✅ **Double-spend Protection**: Prevents multiple refund claims
- ✅ **Balance Verification**: Ensures sufficient funds before purchase

## 🔧 Error Codes

| Code | Description |
|------|-------------|
| `u100` | Unauthorized access |
| `u101` | Resource not found |
| `u102` | Resource already exists |
| `u103` | Invalid amount |
| `u104` | Event not active |
| `u105` | Event canceled |
| `u106` | Refund already claimed |
| `u107` | Oracle unauthorized |

## 📊 Testing

Run the test suite:
```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🌟 Support

If you find this project helpful, please give it a star! ⭐

---

Built with ❤️ using [Clarity](https://clarity-lang.org/) and [Stacks](https://stacks.co/)

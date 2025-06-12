# Spherre: A Decentralized Multisig Treasury Solution for StarkNet


Spherre is an open-source, decentralized multisignature (multisig) treasury solution built for the [StarkNet](https://www.starknet.io/) ecosystem. It enables teams, individuals, and organizations to securely manage digital assets with collective control, transparency, and robust on-chain governance.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)
- [Community](#community)

---

## Features

- **Multisig Treasury:** Require multiple approvals for transactions, reducing single points of failure.
- **Role-Based Access:** Assign roles and permissions to different participants.
- **On-chain Governance:** Propose, approve, and execute treasury actions transparently.
- **Modular & Extensible:** Easily integrate with other StarkNet protocols and dApps.
- **Auditable:** All actions are recorded on-chain for full transparency.

---

## Architecture

- **Cairo Smart Contracts:** Core logic implemented in Cairo, deployed on StarkNet.
- **TypeScript Scripts:** Utilities for deployment, interaction, and testing.
- **Automated Testing:** Uses [Starknet Foundry](https://github.com/foundry-rs/starknet-foundry) for contract testing.
- **Continuous Integration:** GitHub Actions for linting, testing, and formatting.

---

## Getting Started

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- [Starknet Foundry](https://github.com/foundry-rs/starknet-foundry) (`snforge`)
- [Node.js](https://nodejs.org/) (for TypeScript scripts)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Spherre-Labs/spherre.git
   cd spherre
   ```

2. **Install Cairo dependencies:**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
   scarb --version
   ```

3. **Install Starknet Foundry:**
   ```bash
   curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
   snforge --version
   ```

4. **Install Node.js dependencies:**
   ```bash
   npm install
   ```

---

## Development

- **Cairo Contracts:** Located in [`src/`](src/)
- **TypeScript Scripts:** Located in [`scripts-ts/`](scripts-ts/)
- **Deployment Artifacts:** [`deployments/`](deployments/)
- **TypeScript ABIs:** [`typescript_abis/`](typescript_abis/)

### Useful Commands

- **Format Cairo code:**
  ```bash
  scarb fmt
  ```
- **Compile contracts:**
  ```bash
  scarb build
  ```
- **Run Deployment scripts:**
  ```bash
  yarn deploy
  ```

---

## Testing

- **Run all tests:**
  ```bash
  scarb test
  ```

- **Check formatting:**
  ```bash
  scarb fmt --check
  ```

---

## Deployment

1. **Configure environment variables:**  
   Copy `.env.example` to `.env` and fill in the required values.

2. **Deploy contracts:**
   ```bash
   yarn deploy
   ```

3. **Clear deployments (if needed):**
   ```bash
   yarn deploy:clear
   ```

---

## Contributing

We welcome contributions! Please read our [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:

- Setting up your development environment
- Making changes and following the style guide
- Running tests and formatting code
- Submitting pull requests

Please also review our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## License

This project is licensed under the terms of the [MIT License](LICENSE.md).

---

## Community

- **Issues:** [GitHub Issues](https://github.com/Spherre-Labs/spherre/issues)
- **Discussions:** Open a discussion or reach out to the maintainers.


---
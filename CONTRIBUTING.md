# Contributing to Spherre

Thank you for your interest in contributing to our project! We welcome contributions from everyone.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Style Guide](#style-guide)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/your-username/spherre.git
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/Spherre-Labs/spherre.git
   ```

## Development Environment

1. Install required dependencies:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
   curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
   ```

2. Verify installation:
   ```bash
   scarb --version
   snforge --version
   ```


## Making Changes

1. Create a new branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
   or 
   ```bash
   git checkout -b fix/issue-number
   ```


2. Make your changes

3. Follow the [Style Guide](#style-guide)

4. Commit your changes:
   ```bash
   git commit -m "feat: Description of changes"
   ```

## Testing

Before submitting your changes, ensure:

1. All tests pass:
   ```bash
   snforge test
   ```

2. Code is formatted:

   ```bash
   scarb fmt
   ```

## Pull Request Process

1. Update your fork:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. Push your changes:
   ```bash
   git push origin feature/your-feature-name
   ```
   or
   ```bash
   git push origin fix/issue-number 
   ```

3. Open a Pull Request with:
   - Clear title and description
   - Reference to related issues
   - Screenshots/GIFs if applicable
   - Updated documentation

4. Address review feedback

## Style Guide

### Cairo Code Style

- Follow the official [Cairo style guide](https://github.com/starkware-libs/cairo/blob/main/docs/reference/src/components/style-guide/introduction.md)
- Use meaningful variable names
- Add comments for complex logic
- Include docstrings for functions

### Commit Messages

Use these prefixes for commits:

- **feat:** New feature
- **fix:** Bug fix
- **docs:** Documentation changes
- **style:** Non-functional code changes (e.g., formatting)
- **refactor:** Code structure improvements
- **perf:** Performance enhancements
- **test:** Adding or updating tests
- **build:** Build-related changes
- **ci:** CI configuration updates
- **chore:** Non-code changes (e.g., config files)
- **revert:** Reverting a commit

Example:
```
feat: add new component
fix: resolve button click issue
docs: update README
```

## Questions?

Feel free to reach out to the maintainers or open an issue. We're here to help!
# Voltz V2 On-Chain Monorepo

## Package structure

This is a monorepo with the following folder structure and packages:

```
.
├── products                     // Products define the accounting as well as payoff logic of a given derivative contract
│   ├── dated-irs                // Dated Interest Rate Swap Product
│
├── periphery                    // Voltz v2 Periphery
├── core                         // Voltz V2 Core (Margining and Liqiuidation System)
│
└── utils                        // Utilities, plugins, tooling
    ├── common-config            // ..
    ├── core-utils               // ..
    ├── hardhat-storage          // ..
    ├── contracts                // Standard contract implementations like ERC20, adapted for custom router storage
    ├── modules                  // Modules that are reused between multiple router based projects
    └── router                   // Cannon plugin that merges multiple modules into a router contract.
```
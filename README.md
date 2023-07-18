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

# Prerequistes

- Install Node v18 and `yarn` (or `pnpm`)
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Create a personal access token (classic)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) in github with the following permissions: `codespace, project, repo, workflow, write:packages`
- Create global `.yarnrc.yml` file: `touch ~/.yarnrc.yml` and paste the following:
  ```
  npmRegistries:
    https://npm.pkg.github.com/:
      npmAuthToken: <Your GitHub Personal Access Token>
  ```
- Run `yarn` to install dependencies
- Run `forge install` to install other dependencies

# Cannon deployment

- Install latest cannon cli: `npm install -g @usecannon/cli`
- Install cannon router plugin: `cannon plugin add cannon-plugin-router`
- Run `cannon setup` and populate as following:
  - publishing ipfs endpoint: use the api keys from the `v2-cannon-publish` project on Infura. 
  - bulding ipfs endpoint: use the api keys from the `v2-cannon-build` project on Infura. 
  - RPC endpoint: use a mainnet HTTPS endpoint
  - registry address: use default (`0x8E5C7EFC9636A6A0408A46BB7F617094B81e5dba`)
- Change directory to package: e.g., `cd core`
- To deploy/upgrade protocol on arbitrum goerli: 
  - Make sure latest code was compiled: `yarn build`
  - `cannon build cannonfiles/arbitrum_one_goerli.toml --chain-id 421613 --provider-url <PROVIDER_URL> --private-key <PRIVATE_KEY>`


# MULTISIG CONFIGS
- Connect ledger to local app on machine
- `cd integration`
- `MULTISIG=true`, `MULTISIG_ADDRESS=`, `MULTISIG_SEND=true/false`, `WALLET_TYPE=ledger` and `MNEMONIC_INDEX=0` into `.env`
- Populate rest of env variables required for the script (proxies etc)
- `forge script script/ConfigProtocol.s.sol --rpc-url <RPC_URL> --ffi`
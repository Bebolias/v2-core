[![GitHub Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] ![Coverage:Core][coverage-badge]

[gha]: https://github.com/Voltz-Protocol/v2-core/actions
[gha-badge]: https://github.com/Voltz-Protocol/v2-core/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[coverage-badge]: ./core/coverage.svg

# Package Structure

This is a monorepo with the following folder structure and packages:

```
.
├── products                     // Standalone products that extend the core Voltz protocol with new instruments
│   ├── dated-irs                // Dated Interest Rate Swap Product
│
├── core                         // Core Voltz Protocol (to be extended by products)
│
└── utils                        // Utilities, plugins, tooling
    ├── contracts                // Standard contract implementations like ERC20, adapted for custom router storage.
    ├── modules                  // Modules that are reused between multiple router based projects
    └── router                   // Cannon plugin that merges multiple modules into a router contract.
```

# Priorities

**P1**

- Router Generation Process (AB) -> TODO: Need to replace with an example that's relevant to Voltz V2 Router
- Core Deployment (toml syntax) (AB)
- Dated IRS Deployment (AB)
- Dated IRS Market Configuration Module (AB)
- Dated IRS VAMM Pool Implementation in v2-periphery (Cyclops Rex)
- G-TWAP Integration with Rate Oracle Module (Cyclops Rex)
- PRB Math & User Defined Types (Costin)

**P2**

- Semantic Versioning
- Community Deployer (separate module?) -> need to outline the flow in figjam (AB)
- Cannon Tests (AB)
- Fee Module and associated maker/taker fee logic (AB)
- Feature Flag Module (AB)
- Account -> settlement token checks (AB)
- Account -> liquidator deposit logic (AB)
- Consider bringing the .ts tests from https://github.com/Synthetixio/synthetix-v3/tree/main/utils/core-contracts/test/contracts
- Periphery across repos (AB)
- Subgraph Setup (AB)
- SDK Setup (AB)
- Community Deployer (AB)
- Fuzzing
- E2E Testing
- Gas Cost Reduction

**P3**

- Multicall Module
- Differential fuzzing against python repo

# Summary

This project uses foundry. Licensing is not finalised yet, as a placeholder using MIT in a few places to keep the linter happy.

# Router Proxy

Proxy architecture developed by Synthetix referred to as the "Router Proxy".
It is effectively a way to merge several contracts, into a single implementation contract which is the router itself. This router is used as the implementation of the main proxy of the system.

# Comments

For public or external methods and variables, use NatSpec comments.

Forge doc will parse these to autogenerate documentation. Etherscan will display them in the contract UI.

For simple NatSpec comments, consider just documenting params in the docstring, such as
/// @notice Returns the sum of `x` and `y`., instead of using @param tags.

For complex NatSpec comments, consider using a tool like PlantUML (https://plantuml.com/ascii-art) to generate ASCII art diagrams to help explain complex aspects of the codebase.

Any markdown in your comments will carry over properly when generating docs with forge doc, so structure comments with markdown when useful.

Good: /// @notice Returns the sum of `x` and `y`.
Bad: /// @notice Returns the sum of x and y.

# Deployment Guide

To prepare for system upgrades, this repository is used to release new versions of the voltz protocol (core) and products.

## Preparing a release

- Ensure you have the latest version of [Cannon](https://usecannon.com) installed: `npm i -g @usecannon/cli` and `hardhat-cannon` is upgraded to the latest through the repository.
- After installing for the first time, run `cannon setup` to configure IPFS and a reliable RPC endpoint to communicate with the Cannon package registry.
- Run `npm i` and `npm run build` in the root directory of the repository.
- From the directory of the package you're releasing, run `npx hardhat cannon:build`.
  - If you're upgrading the voltz package, also run `npm run build && npx hardhat cannon:build cannonfile.test.toml` to generate the testable package.
  - Confirm the private key that owns the corresponding namespace in the package registry is set in the `.env` file as `DEPLOYER_PRIVATE_KEY`.
  - Publish the release to Cannon package registry with `npx hardhat cannon:publish --network mainnet`.
- Increment the version in the relevant `package.json` files. \_The repositories should always contain the version number of the next release.
- If you've upgraded voltz, also increment the version of the `package.json` file in the root directory. Also upgrade the version in [...]
- Run `npm i` in the root directory.
- Commit and push the change to this repository.
- Then follow the instructions below:

## Specify Upgrade

- After publishing any new versions of the provisioned packages (core, dated irs product), bump the versions throughout the cannonfiles to match.
- Add new settings and invoke actions as necessary
- Update the default values in the network-specific omnibus cannonfiles as desired
- asdf

## Execute Upgrade

Conduct the following process for each network:

- Perform a dry-run and confirm that the actions that would be executed by Cannon are expected:

```
cannon build omnibus-<NETWORK_NAME>.toml --upgrade-from voltz-omnibus:latest --network <RPC_URL_FOR_NETWORK_NAME>  --private-key <DEPLOYER_PRIVATE_KEY> --dry-run
```

- Remove the dry-run option to execute the upgrade:

```
cannon build omnibus-<NETWORK_NAME>.toml --upgrade-from voltz-omnibus:latest --network <RPC_URL_FOR_NETWORK_NAME> --private-key <DEPLOYER_PRIVATE_KEY>
```

### Finalize Release

- Publish your new packages on the Cannon registry:
  - If you upgraded voltz core, `cannon publish voltz:<VERSION_NUMBER> --private-key <KEY_THAT_HAS_ETH_ON_MAINNET> --tags latest,3`
  - `cannon publish synthetix-omnibus:<VERSION_NUMBER> --private-key <KEY_THAT_HAS_ETH_ON_MAINNET> --tags latest,3`
- Increment the version number in each of the omnibus toml files in the root of the repository. (The version in the repository should always be the next version.)
- Commit and merge the change.
- After the new version of the voltz-omnibus package has been published, the previously published packages can be verified on Etherscan.
<<<<<<< HEAD
- From the relevant package's directory, run the following command for each network it was deployed on:  `npx hardhat cannon:verify <PACKAGE_NAME>:<VERSION> --network <NETWORK_NAME>`

# Cannon

From cannon gh (https://github.com/usecannon/cannon): "cannon is under active development. While the interface and functionality are generally stable, use the tool with caution when conducting high-risk deployments".

In order to setup cannon run the following command:

➜ `npx cannon setup `

# Cannon Build

Make sure cannonfile.toml is in the root directory of the project. In order to build the cannon-file for local development and testing run the following command:

➜ `npx cannon build `
example output: `package voltz-core:1.0.0 (ipfs://QmcEaDzQsPdDVrfDi1HaSGTJ9ZXNQexEAbfkecUrT59Xoi)`

The above command creates a local deployment of the core. At this point you should be able to run this package locally using the command-line tool:

➜ `npx cannon voltz-core `
example output: `package voltz-core:latest (ipfs://QmNSntXpk9aueviEVqQDgZ4TNSaYodSMpkQY4uaLQLVViS) voltz-core:latest has been deployed to a local node running at localhost:8545`

# Cannon Deploy

Deploying is effectively just building on a remote network.

`npx cannon build --network REPLACE_WITH_RPC_ENDPOINT --private-key REPLACE_WITH_KEY_THAT_HAS_GAS_TOKENS`

Verify your project’s contracts on Etherscan:

`cannon verify voltz-core --api-key REPLACE_WITH_ETHERSCAN_API_KEY --chain-id REPLACE_WITH_CHAIN_ID`

Finally publish the project to a registry. [...]


=======
- From the relevant package's directory, run the following command for each network it was deployed on: `npx hardhat cannon:verify <PACKAGE_NAME>:<VERSION> --network <NETWORK_NAME>`
>>>>>>> 0c873ca7d6453be5626dd093f4b6a53f46433c40

# Draft Notes

Notes on Associated System

- Associated systems become available to all system modules for communication and interaction, but as opposed to inter-modular communications, interactions with associated systems will require the use of `CALL`.
- Managed systems are connected via a proxy, which means that their implementation can be updated, and the system controls the execution context of the associated system. Example, an snxUSD token connected to the system, and controlled by the system.
- Unmanaged systems are just addresses tracked by the system, for which it has no control whatsoever. Example, Uniswap v3, Curve, etc.

minor

- glp as a service = composability = lp token wars
- permissonless product creation with isolated pool of collateral
- can we cache margin requirement calculations and only apply deltas (trickier with annualization of notionals in case of irs)
- consider breaking down account.sol into further instances beyond just rbac, e.g. one for just margin requirements, etc
- note, pool ids are no a much broader concept, this needs to be elaborated in the architecture diagram and docs
- layer in pool logic and think about how it'd impact the gas costs
- don't think we need cashflow propagation in the collateral engine
- generalise the signature for pools to also include the productId -> creates the ability to have many to many relationships
- because we still haven't fully figured out pools, consider descoping them from mvp
- create a diagram of alternatives for how pools could work vs. mvp
- a product is free to choose what exchange / exchanges to use
- keep products in the core because of the tight dependency with account? -> need to assess pros and cons in more detail
- consider storing the pool address independently in the product contract as a private var or smth and, do we need a pool manager in that instance or just a simple setter within the product will do -> worth thinking this through.
- check out https://github.com/Synthetixio/synthetix-v3/blob/adf3f1f5c2c0967cf68d1489522db87d454f9d78/protocol/synthetix/contracts/modules/core/UtilsModule.sol
- what do they mean by "system wide config for anything" https://github.com/Synthetixio/synthetix-v3/blob/adf3f1f5c2c0967cf68d1489522db87d454f9d78/protocol/synthetix/contracts/storage/Config.sol
- FeatureFlag.ensureAccessToFeature(\_MARKET_FEATURE_FLAG); -> register a new market
- https://github.com/Synthetixio/synthetix-v3/blob/adf3f1f5c2c0967cf68d1489522db87d454f9d78/protocol/synthetix/contracts/modules/core/MarketManagerModule.sol

# TODOs

[![GitHub Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] ![Coverage][coverage-badge]

[gha]: https://github.com/Voltz-Protocol/v2-core/actions
[gha-badge]: https://github.com/Voltz-Protocol/v2-core/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[coverage-badge]: ./coverage.svg

Account

- Market and risk configuration setting process (1)
- Add settlement token related logic (setting, checks, etc) (3)
- Introduce liquidator deposit logic or propose an alternative

- check out https://github.com/Synthetixio/synthetix-v3/blob/adf3f1f5c2c0967cf68d1489522db87d454f9d78/protocol/synthetix/contracts/modules/core/UtilsModule.sol
- what do they mean by "system wide config for anything" https://github.com/Synthetixio/synthetix-v3/blob/adf3f1f5c2c0967cf68d1489522db87d454f9d78/protocol/synthetix/contracts/storage/Config.sol

Liquidation Engine

- reverts and liquidator deposits (4)
- introduce LiquidationData (5)

IRS Product & Pool

- create a new repo for vamms (Ioana)

Fee Logic

- product implementation needs to include fee distribution logic, must be smth the interface supports

Deployment

- sooner rather than later

Macro

- reshuffle files: storage into one folder, core modules into another, external into another, etc

Associated Systems Manager

- [...]

CI

- initial unit tests
- github flows

Math

- PRB Math V3
- User Defined Types

Feature Flags

- FeatureFlag.ensureAccessToFeature(\_MARKET_FEATURE_FLAG); -> register a new market
- https://github.com/Synthetixio/synthetix-v3/blob/adf3f1f5c2c0967cf68d1489522db87d454f9d78/protocol/synthetix/contracts/modules/core/MarketManagerModule.sol

Notes on Associated System

- Associated systems become available to all system modules for communication and interaction, but as opposed to inter-modular communications, interactions with associated systems will require the use of `CALL`.
- Managed systems are connected via a proxy, which means that their implementation can be updated, and the system controls the execution context of the associated system. Example, an snxUSD token connected to the system, and controlled by the system.
- Unmanaged systems are just addresses tracked by the system, for which it has no control whatsoever. Example, Uniswap v3, Curve, etc.

minor

- within each product an account has a portfolio
- check how these base products can represent pools, maturities and markets (bases) as ids, define these in the base dated product contract
- a product can act similar to a manager where it is managing maturities and pools and bases, the product is also a pool manager
- do a single pool for now
- what if pools propagated locked trades to the product instead of the product having to request them, similar to a notify transfer in the account object
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

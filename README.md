# TODOs

Math
- PRB Math V3
- User Defined Types

Liquidation Engine

- how does the liquidation engine talk to the market manager? --> KEY QUESTION!
- where should the account exposures live?

- isAccountIMSatisfied
- getAccountMarginRequirements
- isAccountLiquidatable
- liquidate

minor
- introduce LiquidationData
- introduce ERC20Helper
- introduce Exposure struct

Products

- BaseDatedProduct.sol
- DatedIRSProduct.sol

- add bases, market = product + base + maturity (optional, i.e. not all products are dated)

minor
- check how these base products can represent pools and maturities as ids, define these in the base dated product contract
- glp as a service = composability = lp token wars
- a product can act similar to a manager where it is managing maturities and pools and bases.., the market contract is basically also the pool manager
- unique productId -> product address mapping and then within a given product there may be a few active maturities or a single one, but that's abstracted from the rest of the architecture
- all the maturities of a given account are stored in the product object itself, each product has a single risk parameter, the product abstracts away maturities and pools from the rest of the architecture (mainly the margining system)
- anything else that should be present in IProduct interface?
- what if pools propagated locked trades to the market instead of the market having to request them, similar to a notify transfer in the account object

Feature Flags

- FeatureFlag.ensureAccessToFeature(_MARKET_FEATURE_FLAG); -> register a new market

Account

- turn active products in the account into active bases per product id which returns an array of bases (could just be addresses)
- add settlement token checks
- what if we do margin calculations per product for now, that'd help with bringing down the gas costs (since atm we're doing no correlations)

Pools

- introduce a Pool.sol object, should share similarities with the product object

Oracles

- Oracle Manager -> https://github.com/Synthetixio/synthetix-v3/blob/main/protocol/synthetix/contracts/storage/OracleManager.sol

Notes on Associated System

- Associated systems become available to all system modules for communication and interaction, but as opposed to inter-modular communications, interactions with associated systems will require the use of `CALL`.
-  Managed systems are connected via a proxy, which means that their implementation can be updated, and the system controls the execution context of the associated system. Example, an snxUSD token connected to the system, and controlled by the system.
- Unmanaged systems are just addresses tracked by the system, for which it has no control whatsoever. Example, Uniswap v3, Curve, etc.


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
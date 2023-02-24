# TODOs

Math
- Prb math
- user defined types

Liquidation Engine

- introduce LiquidationData
- introduce ERC20Helper
- introduce Exposure struct

Markets

- implement a mock market & fully define the IMarket interface referencing the python logic
- test market creation and registration flow
- introduce more market tests


Market Manager

- supporting market storage functions that interface with the market address
- include interface for a function that enables the market to query initial margin requirements for a given account?
- anything else that should be present in the IMarket interface?
- mapping between risk parameters and market ids given that now market ids are unique for all maturities now
- what if pools propagated locked trades to the market instead of the market having to request them, similar to a notify transfer in the account object
- kick off irs implementation instead of a mock market and check how it'd fit into the router proxy architecture, maybe a storage can be reserved for the maturities -> glp as a service = composability = lp token wars, a market can act similar to a manager where it is managing maturities and pools, the market contract is basically also the pool manager
- market id + product id for margining purposes
- unique productId -> product address mapping and then within a given product there may be a few active maturities or a single one, but that's abstracted from the rest of the architecture -> rename market to Product or Instrument -> change the market manager, imarket, etc to a product
- all the maturities of a given account are stored in the product object itself, each product has a single risk parameter, the product abstracts away maturities and pools from the rest of the architecture (mainly the margining system)


Feature Flags

- FeatureFlag.ensureAccessToFeature(_MARKET_FEATURE_FLAG); -> register a new market

Account

- getAnnualizedExposures
- AssociatedSystem.load

Pools

- ...

Oracles

- Oracle Manager


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
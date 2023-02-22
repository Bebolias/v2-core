# TODOs

Math
- Prb math
- user defined types

Liquidation Engine

- introduce LiquidationData
- introduce ERC20Helper

Markets

- implement a mock market & fully define the IMarket interface referencing the python logic
- test market creation and registration flow
- introduce more market tests

Account

- getAnnualizedExposures

Pools

- ...


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
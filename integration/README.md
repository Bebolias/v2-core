# Configurations (with multisig support)

- Configurations can be performed by running the `ProtocolConfig.s.sol` script.
- Before doing this, you first need to create an `.env` file within the `integration/` package and populate it with the required information (see `.env.example` for guidance).
- Populate the `run()` function in the script with transactions.
- To run the script, you can execute: `forge script script/ProtocolConfig.s.sol --rpc-url <RPC_URL>`. Note, if `MULTISIG=false`, the script will only simulate transactions and nothing will be published on chain. To execute the transactions on-chain, you have to add `--private-key <PRIVATE_KEY> --broadcast`. To simulate transactions when `MULTISIG=true`, see `MULTISIG_SEND` in `.env.example`.
- By default, the command above will execute the `run()` function. Alternatively, you can run any function by adding `--sig` followed by the function signature and arguments; e.g., `--sig "fun(uint128,address[] memory)" 1 ["0x..","0x.."]`

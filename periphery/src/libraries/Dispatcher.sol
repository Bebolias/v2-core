// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title This library decodes and executes commands
 * @notice This library is called by the ExecutionModule to efficiently decode and execute a singular command
 */
library Dispatcher {
    using BytesLib for bytes;

    error InvalidCommandType(uint256 commandType);
    error BalanceTooLow();

    function dispatch(bytes1 commandType, bytes calldata inputs) internal returns (bool success, bytes memory output) {
        // todo: populate the commands file
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);
        success = true;

        // todo: dig deeper into if boundaries in here https://github.com/Uniswap/universal-router/blob/a88bc6e15af738b61d7bee8feb7df8d2a6e26347/contracts/base/Dispatcher.sol#L40

        if (command == Commands.V2_DatedIRS_SWAP) {
            // todo: add equivalent abi decode
            // todo: decode parameters & execute the swap
        } else if (command == Commands.V2_DATED_IRS_INSTRUMENT_SWAP) {
            // todo: add equivalent abi decode
        } else if (command == Commands.V2_DATED_IRS_INSTRUMENT_SETTLE) {
            // todo: add equivalent abi decode
        } else if (command == Commands.V2_VAMM_EXCHANGE_LP) {
            // todo: add equivalent abi decode
        } else if (command == Commands.V2_CORE_DEPOSIT) {
            // todo: add equivalent abi decode
        } else if (command == Commands.V2_CORE_WITHDRAW) {
            // todo: add equivalent abi decode
        } else if (comamnd == Commands.TRANSFER) {
            // todo: add equivalent abi decode
        } else if (command == Commands.WRAP_ETH) {
            // todo: add equivalent abi decode
        } else if (command == Commands.UNWRAP_ETH) {
            // todo: add equivalent abi decode
        } else {
            // placeholder area for commands ...
            revert InvalidCommandType(command);
        }
    }
}

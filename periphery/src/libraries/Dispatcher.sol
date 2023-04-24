// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./Commands.sol";
import "./V2DatedIRS.sol";
import "./V2Core.sol";

/**
 * @title This library decodes and executes commands
 * @notice This library is called by the ExecutionModule to efficiently decode and execute a singular command
 */
library Dispatcher {
    error InvalidCommandType(uint256 commandType);
    error BalanceTooLow();

    /// @notice Decodes and executes the given command with the given inputs
    /// @param commandType The command type to execute
    /// @param inputs The inputs to execute the command with
    /// @return success True on success of the command, false on failure
    /// @return output The outputs or error messages, if any, from the command
    function dispatch(bytes1 commandType, bytes calldata inputs) internal returns (bool success, bytes memory output) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);
        success = true;

        if (command == Commands.V2_DATED_IRS_INSTRUMENT_SWAP) {
            // equivalent: abi.decode(inputs, (uint128, uint128, uint32, int256))

            uint128 accountId;
            uint128 marketId;
            uint32 maturityTimestamp;
            int256 baseAmount;

            assembly {
                accountId := calldataload(inputs.offset)
                marketId := calldataload(add(inputs.offset, 0x20))
                maturityTimestamp := calldataload(add(inputs.offset, 0x40))
                maturityTimestamp := calldataload(add(inputs.offset, 0x60))
            }
        } else if (command == Commands.V2_DATED_IRS_INSTRUMENT_SETTLE) {
            // todo: add equivalent abi decode
        } else if (command == Commands.V2_CORE_DEPOSIT) {
            // todo: add equivalent abi decode
        } else if (command == Commands.V2_CORE_WITHDRAW) {
            // todo: add equivalent abi decode
        } else if (command == Commands.TRANSFER) {
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

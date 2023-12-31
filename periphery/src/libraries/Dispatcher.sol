// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import "./Constants.sol";
import "./Commands.sol";
import "./V2DatedIRS.sol";
import "./V2DatedIRSVamm.sol";
import "./V2Core.sol";
import "./Payments.sol";

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
    /// @return output Abi encoding of command output if any
    function dispatch(bytes1 commandType, bytes calldata inputs) internal returns (bytes memory output) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        if (command == Commands.V2_DATED_IRS_INSTRUMENT_SWAP) {
            // equivalent: abi.decode(inputs, (uint128, uint128, uint32, int256, uint160))
            uint128 accountId;
            uint128 marketId;
            uint32 maturityTimestamp;
            int256 baseAmount;
            uint160 priceLimit;

            assembly {
                accountId := calldataload(inputs.offset)
                marketId := calldataload(add(inputs.offset, 0x20))
                maturityTimestamp := calldataload(add(inputs.offset, 0x40))
                baseAmount := calldataload(add(inputs.offset, 0x60))
                priceLimit := calldataload(add(inputs.offset, 0x80))
            }

            (
                int256 executedBaseAmount,
                int256 executedQuoteAmount,
                uint256 fee,
                uint256 im,
                uint256 highestUnrealizedLoss,
                int24 currentTick
            ) = V2DatedIRS.swap(accountId, marketId, maturityTimestamp, baseAmount, priceLimit);
            output = abi.encode(executedBaseAmount, executedQuoteAmount, fee, im, highestUnrealizedLoss, currentTick);
        } else if (command == Commands.V2_DATED_IRS_INSTRUMENT_SETTLE) {
            // equivalent: abi.decode(inputs, (uint128, uint128, uint32))
            uint128 accountId;
            uint128 marketId;
            uint32 maturityTimestamp;
            assembly {
                accountId := calldataload(inputs.offset)
                marketId := calldataload(add(inputs.offset, 0x20))
                maturityTimestamp := calldataload(add(inputs.offset, 0x40))
            }
            V2DatedIRS.settle(accountId, marketId, maturityTimestamp);
        } else if (command == Commands.V2_VAMM_EXCHANGE_LP) {
            // equivalent: abi.decode(inputs, (uint128, uint128, uint32, int24, int24, int128))
            uint128 accountId;
            uint128 marketId;
            uint32 maturityTimestamp;
            int24 tickLower;
            int24 tickUpper;
            int128 liquidityDelta;
            assembly {
                accountId := calldataload(inputs.offset)
                marketId := calldataload(add(inputs.offset, 0x20))
                maturityTimestamp := calldataload(add(inputs.offset, 0x40))
                tickLower := calldataload(add(inputs.offset, 0x60))
                tickUpper := calldataload(add(inputs.offset, 0x80))
                liquidityDelta := calldataload(add(inputs.offset, 0xA0))
            }
            (uint256 fee, uint256 im, uint256 highestUnrealizedLoss) = V2DatedIRSVamm.initiateDatedMakerOrder(
                accountId,
                marketId,
                maturityTimestamp,
                tickLower,
                tickUpper,
                liquidityDelta
            );
            output = abi.encode(fee, im, highestUnrealizedLoss);
        } else if (command == Commands.V2_CORE_CREATE_ACCOUNT) {
            // equivalent: abi.decode(inputs, (uint128))
            uint128 requestedId;
            assembly {
                requestedId := calldataload(inputs.offset)
            }

            // todo: missing tests for this flow, no tests failed after changing the implementation (IR)
            V2Core.createAccount(requestedId);
        } else if (command == Commands.V2_CORE_DEPOSIT) {
            // equivalent: abi.decode(inputs, (uint128, address, uint256))
            uint128 accountId;
            address collateralType;
            uint256 tokenAmount;
            assembly {
                accountId := calldataload(inputs.offset)
                collateralType := calldataload(add(inputs.offset, 0x20))
                tokenAmount := calldataload(add(inputs.offset, 0x40))
            }
            V2Core.deposit(accountId, collateralType, tokenAmount);
        } else if (command == Commands.V2_CORE_WITHDRAW) {
            // equivalent: abi.decode(inputs, (uint128, address, uint256))
            uint128 accountId;
            address collateralType;
            uint256 tokenAmount;
            assembly {
                accountId := calldataload(inputs.offset)
                collateralType := calldataload(add(inputs.offset, 0x20))
                tokenAmount := calldataload(add(inputs.offset, 0x40))
            }
            V2Core.withdraw(accountId, collateralType, tokenAmount);
        } else if (command == Commands.WRAP_ETH) {
            // equivalent: abi.decode(inputs, (uint256))
            uint256 amountMin;
            assembly {
                amountMin := calldataload(inputs.offset)
            }
            Payments.wrapETH(address(this), amountMin);
        } else if (command == Commands.TRANSFER_FROM) {
            // equivalent: abi.decode(inputs, (address, uint160))
            address token;
            uint160 value;
            assembly {
                token := calldataload(inputs.offset)
                value := calldataload(add(inputs.offset, 0x20))
            }
            Payments.transferFrom(token, msg.sender, address(this), value);
        } else {
            // placeholder area for commands ...
            revert InvalidCommandType(command);
        }
    }
}

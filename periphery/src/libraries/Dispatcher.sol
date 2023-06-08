// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./Constants.sol";
import "./Commands.sol";
import "./V2DatedIRS.sol";
import "./V2DatedIRSVamm.sol";
import "./V2Core.sol";
import "./Payments.sol";
import "./Permit2Payments.sol";

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
    function dispatch(bytes1 commandType, bytes calldata inputs) internal returns (bool success) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);
        success = true;

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

            V2DatedIRS.swap(accountId, marketId, maturityTimestamp, baseAmount, priceLimit);
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
            V2DatedIRSVamm.initiateDatedMakerOrder(accountId, marketId, maturityTimestamp, tickLower, tickUpper, liquidityDelta);
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
            // equivalent: abi.decode(inputs, (address, address, uint160))
            address token;
            address from;
            uint160 value;
            assembly {
                token := calldataload(inputs.offset)
                from := calldataload(add(inputs.offset, 0x20))
                value := calldataload(add(inputs.offset, 0x40))
            }
            Permit2Payments.permit2TransferFrom(token, from, address(this), value);
        } else {
            // placeholder area for commands ...
            revert InvalidCommandType(command);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../../src/interfaces/external/IAllowanceTransfer.sol";


contract MockAllowanceTransfer is IAllowanceTransfer {

    uint256 i;

    /// @inheritdoc IAllowanceTransfer
    function approve(address token, address spender, uint160 amount, uint48 expiration) external {
        i = 1;
    }

    /// @inheritdoc IAllowanceTransfer
    function allowance(address a, address b, address c) external view returns (uint160, uint48, uint48) {
        return (1, 1, 1);
    }

    /// @inheritdoc IAllowanceTransfer
    function permit(address owner, PermitSingle memory permitSingle, bytes calldata signature) external {
        i = 1;
    }

    /// @inheritdoc IAllowanceTransfer
    function permit(address owner, PermitBatch memory permitBatch, bytes calldata signature) external {
        i = 1;
    }

    /// @inheritdoc IAllowanceTransfer
    function transferFrom(address from, address to, uint160 amount, address token) external {
        i = 1;
    }

    /// @inheritdoc IAllowanceTransfer
    function transferFrom(AllowanceTransferDetails[] calldata transferDetails) external {
        i = 1;
    }

    /// @inheritdoc IAllowanceTransfer
    function lockdown(TokenSpenderPair[] calldata approvals) external {
        i = 1;
    }

    /// @inheritdoc IAllowanceTransfer
    function invalidateNonces(address token, address spender, uint48 newNonce) external {
        i = 1;
    }
}
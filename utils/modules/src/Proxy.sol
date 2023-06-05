// solhint-disable no-empty-blocks

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import {UUPSProxyWithOwner} from "@voltz-protocol/util-contracts/src/proxy/UUPSProxyWithOwner.sol";

contract Proxy is UUPSProxyWithOwner {
    constructor(address firstImplementation, address initialOwner)
        UUPSProxyWithOwner(firstImplementation, initialOwner)
    {}
}

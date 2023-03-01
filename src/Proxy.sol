//SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./utils/contracts/proxy/UUPSProxyWithOwner.sol";

contract Proxy is UUPSProxyWithOwner {
    // solhint-disable-next-line no-empty-blocks
    constructor(address firstImplementation, address initialOwner) UUPSProxyWithOwner(firstImplementation, initialOwner) { }
}

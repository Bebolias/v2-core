// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/Test.sol";

error Unauthorized();

contract OwnerOnly {
    address public immutable owner;
    uint256 public count;

    constructor() { 
        owner = msg.sender;
    }
    
    function increment() external {
        if(msg.sender != owner) {
            revert Unauthorized();
        }
        count++;
    }
}


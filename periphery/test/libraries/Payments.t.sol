//SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/libraries/Payments.sol";
import "../../src/storage/Config.sol";
import "../../src/interfaces/external/IAllowanceTransfer.sol";

contract ExposedPayments {
    function setUp(Config.Data memory config) external {
        Config.set(config);
    }

    // exposed functions
    function pay(address token, address recipient, uint256 value) external {
        Payments.pay(token, recipient, value);
    }

    function wrapETH(address recipient, uint256 amount) external {
        Payments.wrapETH(recipient, amount);
    }

    function unwrapWETH9(address recipient, uint256 amountMinimum) external {
        Payments.unwrapWETH9(recipient, amountMinimum);
    }
}

contract PaymentsTest is Test {
    ExposedPayments internal exposedPayments;

    function setUp(IWETH9 weth9) public {
        exposedPayments = new ExposedPayments();
        exposedPayments.setUp(
            Config.Data({
                WETH9: weth9,
                PERMIT2: IAllowanceTransfer(address(0)),
                VOLTZ_V2_CORE_PROXY: address(0),
                VOLTZ_V2_DATED_IRS_PROXY: address(0),
                VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(0)
            })
        );
    }

    function testWrapETH() public {
        vm.deal(address(exposedPayments), 1 ether);
        IWETH9 weth9 = IWETH9(address(1));
        vm.mockCall(weth9, 1 ether, abi.encodeWithSelector(IWETH9.deposit.selector), abi.encode((0)));
        vm.mockCall(weth9, abi.encodeWithSelector(IWETH9.transfer.selector, address(2), 1 ether), abi.encode((0)));
        exposedPayments.wrapETH(address(2), 1 ether);
        vm.expectCall(weth9, 1 ether, abi.encodeWithSelector(IWETH9.deposit.selector));
        vm.expectCall(weth9, abi.encodeWithSelector(IWETH9.transfer.selector, address(2), 1 ether));
    }
}

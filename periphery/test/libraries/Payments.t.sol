pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "../../src/libraries/Payments.sol";
import "../../src/libraries/Constants.sol";
import "../../src/storage/Config.sol";
import "../../src/interfaces/external/IAllowanceTransfer.sol";
import "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";
import "solmate/src/utils/SafeTransferLib.sol";

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

    function setUp() public {
        exposedPayments = new ExposedPayments();
        exposedPayments.setUp(
            Config.Data({
                WETH9: IWETH9(address(1)),
                PERMIT2: IAllowanceTransfer(address(0)),
                VOLTZ_V2_CORE_PROXY: address(0),
                VOLTZ_V2_DATED_IRS_PROXY: address(0),
                VOLTZ_V2_DATED_IRS_VAMM_PROXY: address(0),
                VOLTZ_V2_ACCOUNT_NFT_PROXY: address(0)
            })
        );
    }

    function testWrapETH() public {
        vm.deal(address(exposedPayments), 2 ether);
        IWETH9 weth9 = IWETH9(address(1));
        vm.mockCall(address(weth9), 1 ether, abi.encodeWithSelector(IWETH9.deposit.selector), abi.encode((0)));
        vm.mockCall(
            address(weth9), abi.encodeWithSelector(IERC20.transfer.selector, address(2), 1 ether), abi.encode((0))
        );
        vm.expectCall(address(weth9), abi.encodeWithSelector(IERC20.transfer.selector, address(2), 1 ether));
        vm.expectCall(address(weth9), 1 ether, abi.encodeWithSelector(IWETH9.deposit.selector));
        exposedPayments.wrapETH(address(2), 1 ether);
    }

    function testWrapETHInsufficientEth() public {
        IWETH9 weth9 = IWETH9(address(1));
        vm.mockCall(address(weth9), 1 ether, abi.encodeWithSelector(IWETH9.deposit.selector), abi.encode((0)));
        vm.mockCall(
            address(weth9), abi.encodeWithSelector(IERC20.transfer.selector, address(2), 1 ether), abi.encode((0))
        );
        vm.expectRevert(abi.encodeWithSelector(Payments.InsufficientETH.selector));
        exposedPayments.wrapETH(address(2), 1 ether);
    }

    function testWrapETHContractBalance() public {
        vm.deal(address(exposedPayments), 2 ether);
        IWETH9 weth9 = IWETH9(address(1));
        vm.mockCall(address(weth9), 2 ether, abi.encodeWithSelector(IWETH9.deposit.selector), abi.encode((0)));
        vm.mockCall(
            address(weth9), abi.encodeWithSelector(IERC20.transfer.selector, address(2), 2 ether), abi.encode((0))
        );
        vm.expectCall(address(weth9), abi.encodeWithSelector(IERC20.transfer.selector, address(2), 2 ether));
        vm.expectCall(address(weth9), 2 ether, abi.encodeWithSelector(IWETH9.deposit.selector));
        exposedPayments.wrapETH(address(2), Constants.CONTRACT_BALANCE);
    }

    function testUnwrapWETH9() public {
        vm.deal(address(exposedPayments), 2 ether);
        IWETH9 weth9 = IWETH9(address(1));
        vm.mockCall(address(weth9), 0, abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(2 ether));
        vm.mockCall(address(weth9), abi.encodeWithSelector(IWETH9.withdraw.selector, 2 ether), abi.encode(0));
        vm.mockCall(
            address(exposedPayments), 1 ether, abi.encodeWithSelector(exposedPayments.pay.selector), abi.encode(0)
        );

        vm.expectCall(address(weth9), 0, abi.encodeWithSelector(IERC20.balanceOf.selector));
        exposedPayments.unwrapWETH9(address(3), 1 ether);
    }
}

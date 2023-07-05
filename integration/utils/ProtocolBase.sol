pragma solidity >=0.8.19;

import {BatchScript} from "../utils/BatchScript.sol";

import {CoreProxy, AccountNftProxy} from "../src/Core.sol";
import {DatedIrsProxy} from "../src/DatedIrs.sol";
import {PeripheryProxy} from "../src/Periphery.sol";
import {VammProxy} from "../src/Vamm.sol";

import {AccessPassNFT} from "@voltz-protocol/access-pass-nft/src/AccessPassNFT.sol";

import {AccessPassConfiguration} from "@voltz-protocol/core/src/storage/AccessPassConfiguration.sol";
import {CollateralConfiguration} from "@voltz-protocol/core/src/storage/CollateralConfiguration.sol";
import {ProtocolRiskConfiguration} from "@voltz-protocol/core/src/storage/ProtocolRiskConfiguration.sol";
import {MarketFeeConfiguration} from "@voltz-protocol/core/src/storage/MarketFeeConfiguration.sol";
import {MarketRiskConfiguration} from "@voltz-protocol/core/src/storage/MarketRiskConfiguration.sol";
import {AaveV3RateOracle} from "@voltz-protocol/products-dated-irs/src/oracles/AaveV3RateOracle.sol";
import {AaveV3BorrowRateOracle} from "@voltz-protocol/products-dated-irs/src/oracles/AaveV3BorrowRateOracle.sol";

import {ProductConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/ProductConfiguration.sol";
import {MarketConfiguration} from "@voltz-protocol/products-dated-irs/src/storage/MarketConfiguration.sol";

import {VammConfiguration} from "@voltz-protocol/v2-vamm/utils/vamm-math/VammConfiguration.sol";

import {Config} from "@voltz-protocol/periphery/src/storage/Config.sol";

import {Ownable} from "@voltz-protocol/util-contracts/src/ownership/Ownable.sol";
import {IERC20} from "@voltz-protocol/util-contracts/src/interfaces/IERC20.sol";

contract ProtocolBase is BatchScript {
  uint256 internal chainId;

  CoreProxy internal coreProxy = CoreProxy(payable(vm.envAddress("CORE_PROXY")));
  DatedIrsProxy internal datedIrsProxy = DatedIrsProxy(payable(vm.envAddress("DATED_IRS_PROXY")));
  PeripheryProxy internal peripheryProxy = PeripheryProxy(payable(vm.envAddress("PERIPHERY_PROXY")));
  VammProxy internal vammProxy = VammProxy(payable(vm.envAddress("VAMM_PROXY")));

  AaveV3RateOracle internal aaveV3RateOracle = AaveV3RateOracle(vm.envAddress("AAVE_V3_RATE_ORACLE"));
  AaveV3BorrowRateOracle internal aaveV3BorrowRateOracle = AaveV3BorrowRateOracle(vm.envAddress("AAVE_V3_BORROW_RATE_ORACLE"));

  AccessPassNFT internal accessPassNft = AccessPassNFT(vm.envAddress("ACCESS_PASS_NFT"));
  AccountNftProxy internal accountNftProxy;

  address internal owner = coreProxy.owner();

  bool internal multisig = vm.envBool("MULTISIG");
  address internal multisigAddress;
  bool internal multisigSend;

  bytes32 internal constant _GLOBAL_FEATURE_FLAG = "global";
  bytes32 internal constant _CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";
  bytes32 internal constant _NOTIFY_ACCOUNT_TRANSFER_FEATURE_FLAG = "notifyAccountTransfer";
  bytes32 internal constant _REGISTER_PRODUCT_FEATURE_FLAG = "registerProduct";

  constructor() {
    if (multisig) {
      multisigAddress = vm.envAddress("MULTISIG_ADDRESS");
      multisigSend = vm.envBool("MULTISIG_SEND");
    }

    (address accountNftProxyAddress, ) = coreProxy.getAssociatedSystem(bytes32("accountNFT"));
    accountNftProxy = AccountNftProxy(payable(accountNftProxyAddress));

    Chain memory chain = getChain(vm.envString("CHAIN"));
    chainId = chain.chainId;
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////               ERC20              /////////////////
  ////////////////////////////////////////////////////////////////////

  function erc20_approve(IERC20 token, address spender, uint256 amount) public {
    if (!multisig) {
      vm.broadcast(owner);
      token.approve(spender, amount);
    } else {
      addToBatch(
        address(token),
        abi.encodeCall(
          token.approve,
          (spender, amount)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////             CORE PROXY           /////////////////
  ////////////////////////////////////////////////////////////////////

  function acceptOwnership(address ownableProxyAddress) public {
    if (!multisig) {
      vm.broadcast(owner);
      Ownable(ownableProxyAddress).acceptOwnership();
    } else {
      addToBatch(
        ownableProxyAddress,
        abi.encodeCall(
          Ownable.acceptOwnership,
          ()
        )
      );
    }
  }

  function setFeatureFlagAllowAll(bytes32 feature, bool allowAll) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.setFeatureFlagAllowAll(
        feature, allowAll
      );
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.setFeatureFlagAllowAll, 
          (feature, allowAll)
        )
      );
    }
  }

  function addToFeatureFlagAllowlist(bytes32 feature, address account) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.addToFeatureFlagAllowlist(feature, account);
    } else {
      addToBatch(
        address(coreProxy), 
        abi.encodeCall(
          coreProxy.addToFeatureFlagAllowlist, 
          (feature, account)
        )
      );
    }
  }

  function setPeriphery(address peripheryAddress) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.setPeriphery(peripheryAddress);
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.setPeriphery,
          (peripheryAddress)
        )
      );
    }
  }

  function configureMarketRisk(MarketRiskConfiguration.Data memory config) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.configureMarketRisk(config);
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.configureMarketRisk,
          (config)
        )
      );
    }
  }

  function configureProtocolRisk(ProtocolRiskConfiguration.Data memory config) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.configureProtocolRisk(config);
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.configureProtocolRisk,
          (config)
        )
      );
    }
  }

  function configureAccessPass(AccessPassConfiguration.Data memory config) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.configureAccessPass(config);
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.configureAccessPass,
          (config)
        )
      );
    }
  }

  function registerProduct(address product, string memory name) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.registerProduct(product, name);
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.registerProduct,
          (product, name)
        )
      );
    }
  }

  function configureCollateral(CollateralConfiguration.Data memory config) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.configureCollateral(config);
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.configureCollateral,
          (config)
        )
      );
    }
  }

  function createAccount(uint128 requestedAccountId, address accountOwner) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.createAccount(requestedAccountId, accountOwner);
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.createAccount,
          (requestedAccountId, accountOwner)
        )
      );
    }
  }

  function configureMarketFee(MarketFeeConfiguration.Data memory config) public {
    if (!multisig) {
      vm.broadcast(owner);
      coreProxy.configureMarketFee(config);
    } else {
      addToBatch(
        address(coreProxy),
        abi.encodeCall(
          coreProxy.configureMarketFee,
          (config)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////             DATED IRS            /////////////////
  ////////////////////////////////////////////////////////////////////

  function configureProduct(ProductConfiguration.Data memory config) public {
    if (!multisig) {
      vm.broadcast(owner);
      datedIrsProxy.configureProduct(config);
    } else {
      addToBatch(
        address(datedIrsProxy),
        abi.encodeCall(
          datedIrsProxy.configureProduct,
          (config)
        )
      );
    }
  }

  function configureMarket(MarketConfiguration.Data memory config) public {
    if (!multisig) {
      vm.broadcast(owner);
      datedIrsProxy.configureMarket(config);
    } else {
      addToBatch(
        address(datedIrsProxy),
        abi.encodeCall(
          datedIrsProxy.configureMarket,
          (config)
        )
      );
    }
  }

  function setVariableOracle(uint128 marketId, address oracleAddress, uint256 maturityIndexCachingWindowInSeconds) public {
    if (!multisig) {
      vm.broadcast(owner);
      datedIrsProxy.setVariableOracle(marketId, oracleAddress, maturityIndexCachingWindowInSeconds);
    } else {
      addToBatch(
        address(datedIrsProxy),
        abi.encodeCall(
          datedIrsProxy.setVariableOracle,
          (marketId, oracleAddress, maturityIndexCachingWindowInSeconds)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////                VAMM              /////////////////
  ////////////////////////////////////////////////////////////////////

  function setProductAddress(address productAddress) public {
    if (!multisig) {
      vm.broadcast(owner);
      vammProxy.setProductAddress(productAddress);
    } else {
      addToBatch(
        address(vammProxy),
        abi.encodeCall(
          vammProxy.setProductAddress,
          (productAddress)
        )
      );
    }
  }

  function createVamm(
    uint128 marketId, 
    uint160 sqrtPriceX96, 
    VammConfiguration.Immutable memory config, 
    VammConfiguration.Mutable memory mutableConfig
  ) public {
    if (!multisig) {
      vm.broadcast(owner);
      vammProxy.createVamm(marketId, sqrtPriceX96, config, mutableConfig);
    } else {
      addToBatch(
        address(vammProxy),
        abi.encodeCall(
          vammProxy.createVamm,
          (marketId, sqrtPriceX96, config, mutableConfig)
        )
      );
    }
  }

  function increaseObservationCardinalityNext(
    uint128 marketId, 
    uint32 maturityTimestamp, 
    uint16 observationCardinalityNext
  ) public {
    if (!multisig) {
      vm.broadcast(owner);
      vammProxy.increaseObservationCardinalityNext(
        marketId, maturityTimestamp, observationCardinalityNext
      );
    } else {
      addToBatch(
        address(vammProxy),
        abi.encodeCall(
          vammProxy.increaseObservationCardinalityNext,
          (marketId, maturityTimestamp, observationCardinalityNext)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////             PERIPHERY            /////////////////
  ////////////////////////////////////////////////////////////////////

  function periphery_configure(Config.Data memory config) public {
    if (!multisig) {
      vm.broadcast(owner);
      peripheryProxy.configure(config);
    } else {
      addToBatch(
        address(peripheryProxy),
        abi.encodeCall(
          peripheryProxy.configure,
          (config)
        )
      );
    }
  }

  function periphery_execute(bytes memory commands, bytes[] memory inputs, uint256 deadline) public {
    if (!multisig) {
      vm.broadcast(owner);
      peripheryProxy.execute(commands, inputs, deadline);
    } else {
      addToBatch(
        address(peripheryProxy),
        abi.encodeCall(
          peripheryProxy.execute,
          (commands, inputs, deadline)
        )
      );
    }
  }

  ////////////////////////////////////////////////////////////////////
  /////////////////          ACCESS PASS NFT         /////////////////
  ////////////////////////////////////////////////////////////////////

  function addNewRoot(AccessPassNFT.RootInfo memory rootInfo) public {
    if (!multisig) {
      vm.broadcast(owner);
      accessPassNft.addNewRoot(rootInfo);
    } else {
      addToBatch(
        address(accessPassNft),
        abi.encodeCall(
          accessPassNft.addNewRoot,
          (rootInfo)
        )
      );
    }
  }
}
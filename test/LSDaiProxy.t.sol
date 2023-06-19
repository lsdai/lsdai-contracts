// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// upgradeable proxy
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {LSDAITestBase, MAKER_POT} from "./common/LSDAITestBase.sol";
import {LSDai} from "../contracts/LSDai.sol";
import {ILSDai} from "../contracts/interfaces/ILSDai.sol";

contract LSDaiTests is LSDAITestBase {
  function test_CanBeUsedInProxy() public {
    LSDai lsdai = new LSDai();
    // initialize LSDai
    // lsdai.initialize();

    // deploy proxy admin
    ProxyAdmin proxyAdmin = new ProxyAdmin();

    // deploy proxy
    TransparentUpgradeableProxy tuProxy = new TransparentUpgradeableProxy(address(lsdai), address(proxyAdmin), '');

    // initialize proxy
    ILSDai lsdaiProxy = ILSDai(address(tuProxy));

    uint256 _depositCap = 5000;
    uint256 _interestFee = 100;
    uint256 _withdrawalFee = 2;
    address _feeRecipient = address(this);

    lsdaiProxy.initialize(_depositCap, _interestFee, _withdrawalFee, _feeRecipient);

    // check that LSDai is initialized
    assertEq(lsdaiProxy.depositCap(), _depositCap);
    assertEq(lsdaiProxy.interestFee(), _interestFee);
    assertEq(lsdaiProxy.withdrawalFee(), _withdrawalFee);
    assertEq(lsdaiProxy.feeRecipient(), _feeRecipient);

    assertEq(lsdaiProxy.totalSupply(), 0);
    assertEq(lsdaiProxy.totalShares(), 0);
  }
}

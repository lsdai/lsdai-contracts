// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// upgradeable proxy
import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';

import {LSDAITestBase, MAKER_POT} from './common/LSDAITestBase.sol';
import {LSDai} from '../contracts/LSDai.sol';
import {ILSDai} from '../contracts/interfaces/ILSDai.sol';

contract LSDaiTests is LSDAITestBase {
  LSDai lsdaiImplementation;
  ProxyAdmin proxyAdmin;
  LSDai lsdaiProxy;

  // LSDai users
  address lsdTripper = address(0x23);
  address lsdEnjoyer = address(0x24);
  address lsdDreamer = address(0x25);

  function setUp() public {
    // deploy proxy admin
    proxyAdmin = new ProxyAdmin();

    lsdaiImplementation = new LSDai();
    // deploy proxy admin
    proxyAdmin = new ProxyAdmin();
    // deploy proxy
    TransparentUpgradeableProxy tuProxy = new TransparentUpgradeableProxy(
      address(lsdaiImplementation),
      address(proxyAdmin),
      ''
    );
    // initialize proxy
    lsdaiProxy = LSDai(address(tuProxy));

    uint256 _depositCap = 100_000 ether;
    uint256 _interestFee = 250;
    uint256 _withdrawalFee = 1;
    address _feeRecipient = address(this);
    lsdaiProxy.initialize(_depositCap, _interestFee, _withdrawalFee, _feeRecipient);
  }

  function test_CanBeUsedInProxy() public {
    // deploy proxy
    TransparentUpgradeableProxy tuProxy = new TransparentUpgradeableProxy(
      address(lsdaiImplementation),
      address(proxyAdmin),
      ''
    );
    // initialize proxy
    lsdaiProxy = LSDai(address(tuProxy));

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

  function test_UserCanWithdrawRecievedLSDAI() public {
    mintDAI(lsdTripper, 10_000 ether);

    uint256 initialDeposit = dai.balanceOf(lsdTripper);
    // Deposit everything into LSDai
    depositDAI(lsdaiProxy, lsdTripper, initialDeposit);
    assertEq(dai.balanceOf(lsdTripper), 0, 'LSD tripper should have 0 DAI');
    // 1:1 ratio
    assertEq(lsdaiProxy.balanceOf(lsdTripper), initialDeposit, 'LSD tripper should have initial deposit');
    assertEq(lsdaiProxy.balanceOf(lsdEnjoyer), 0, 'LSD Enjoyer should have 0 LSDai');

    vm.warp(block.timestamp + 52 weeks);
    lsdaiProxy.rebase();

    // Take 1000 LSDAI from LSD tripper and give it to LSD Enjoyer
    uint256 amountToTransfer = 1000 ether;
    vm.prank(lsdTripper);
    lsdaiProxy.transfer(lsdEnjoyer, amountToTransfer);
    // assertEq(lsdai.balanceOf(lsdEnjoyer), amountToTransfer, 'LSD Enjoyer should have 1000 LSDai');

    // LSD enjoyer withdraws 1000 LSDai
    withdrawDAI(lsdaiProxy, lsdEnjoyer, lsdaiProxy.balanceOf(lsdEnjoyer));
  }
}

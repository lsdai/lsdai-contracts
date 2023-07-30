// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {LSDAITestBase, MAKER_POT} from "./common/LSDAITestBase.sol";
import {LSDai} from "../contracts/LSDai.sol";
import {IDai} from "../contracts/interfaces/IDai.sol";

address constant DAI_ADDRESS = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

contract LSDaiTests is LSDAITestBase {
  using SafeMath for uint256;
  // Test events

  event Transfer(address indexed from, address indexed to, uint256 value);
  event TransferShares(address indexed from, address indexed to, uint256 sharesValue);
  event SharesBurnt(
    address indexed account, uint256 preRebaseTokenAmount, uint256 postRebaseTokenAmount, uint256 sharesAmount
  );

  LSDai lsdai;

  // LSDai users
  address lsdTripper = address(0x23);
  address lsdEnjoyer = address(0x24);
  address lsdDreamer = address(0x25);

  uint256 lsdTripperInitialDeposit = 10_000_000 ether;
  uint256 lsdEnjoyerInitialDeposit = 20_000_000 ether;
  uint256 lsdDreamerInitialDeposit = 70_000_000 ether;

  function setUp() public {
    mintDAI(lsdTripper, lsdTripperInitialDeposit);
    mintDAI(lsdEnjoyer, lsdEnjoyerInitialDeposit);
    mintDAI(lsdDreamer, lsdDreamerInitialDeposit);
    lsdai = new LSDai();
    // initialize LSDai
    lsdai.initialize(
      150_000_000 ether, // 150M DAI deposit cap
      250, // 0.25% interest fee
      1, // 0.01% withdrawal fee
      address(this) // fee recipient
    );
  }

  function test_lsdaiCanBeIntializedOnce() public {
    vm.expectRevert(LSDai.LSDai__AlreadyInitialized.selector);
    // initialize LSDai
    lsdai.initialize(
      150_000_000 ether, // 150M DAI deposit cap
      250, // 0.25% interest fee
      1, // 0.01% withdrawal fee
      address(this) // fee recipient
    );
  }

  function test_lsdaiIsERC20ish() public {
    // Check if the contract implements the ERC20 interface
    assertEq(lsdai.symbol(), "LSDAI");
    assertEq(lsdai.name(), "Liquid Savings DAI");
    assertEq(lsdai.decimals(), 18);

    // Deposit DAI from LSD tripper
    depositDAI(lsdTripper, lsdTripperInitialDeposit);

    // Test allowance
    assertEq(lsdai.allowance(lsdTripper, lsdEnjoyer), 0);
    vm.prank(lsdTripper);
    lsdai.approve(lsdEnjoyer, 1000 ether);
    assertEq(lsdai.allowance(lsdTripper, lsdEnjoyer), 1000 ether);

    // Test transfer
    {
      uint256 lsdaiTripperBalanceBeforeTransfer = lsdai.balanceOf(lsdTripper);

      // Expected balance and shares to transfer
      uint256 balanceToTransfer = 1000 ether;
      uint256 expectedSharesToTransfer = lsdai.getSharesByPooledDai(balanceToTransfer);

      vm.prank(lsdTripper);
      vm.expectEmit();

      emit Transfer(lsdTripper, lsdEnjoyer, balanceToTransfer);
      emit TransferShares(lsdTripper, lsdEnjoyer, expectedSharesToTransfer);
      lsdai.transfer(lsdEnjoyer, balanceToTransfer);
      // Check LSD Tripper balance
      assertEq(lsdai.balanceOf(lsdTripper), lsdaiTripperBalanceBeforeTransfer - balanceToTransfer);
      assertEq(
        lsdai.sharesOf(lsdTripper), lsdai.getSharesByPooledDai(lsdaiTripperBalanceBeforeTransfer - balanceToTransfer)
      );
      // Check LSD Enjoyer balance
      assertEq(lsdai.balanceOf(lsdEnjoyer), balanceToTransfer);
      assertEq(lsdai.sharesOf(lsdEnjoyer), expectedSharesToTransfer);
    }
  }

  function test_withdrawalFee() public {
    // Deposit DAI from LSD tripper
    depositDAI(lsdTripper, lsdTripperInitialDeposit);

    // lsdtripper original dai balance
    uint256 lsdTripperOriginalDAIBalance = dai.balanceOf(lsdTripper);

    // LSDai fee recipient balance should have 0 shares
    assertEq(lsdai.sharesOf(lsdai.feeRecipient()), 0);

    // withdraw 1000000 DAI
    uint256 testWithdrawAmount = 1000000 ether;
    // get withdrawal fee for accounting
    uint256 withdrawalFee = lsdai.withdrawalFee(); // 0.01% per now
    // expected received amount
    uint256 expectedFeeAmount = (testWithdrawAmount * withdrawalFee) / 10_000;

    // Expected withdraw amount after fees
    uint256 expectedWithdrawAmount = testWithdrawAmount - expectedFeeAmount;

    // Expected shares to burn from the LSD tripper
    uint256 expectedSharesToBurn = lsdai.getSharesByPooledDai(expectedWithdrawAmount);
    uint256 expectedPreRebaseTokenAmount = lsdai.getPooledDaiByShares(expectedSharesToBurn);

    uint256 expectedTotalLSDaiSharesAfterBurn = lsdai.totalShares() - expectedSharesToBurn;

    uint256 expectedPostRebaseTokenAmount =
      expectedSharesToBurn.mul(expectedTotalLSDaiSharesAfterBurn).div(expectedTotalLSDaiSharesAfterBurn);

    // Submit withdrawal request
    vm.prank(lsdTripper);
    vm.expectEmit(address(lsdai));
    emit Transfer(lsdTripper, address(0), expectedWithdrawAmount);
    // // Assert that lsd tripper shares are burnt
    emit SharesBurnt(lsdTripper, 899919999000000000000000, expectedPostRebaseTokenAmount, expectedSharesToBurn);
    lsdai.withdraw(testWithdrawAmount);

    assertEq(lsdai.balanceOf(lsdTripper), lsdTripperInitialDeposit - testWithdrawAmount);

    // LSD tripper received the expected amount of DAI
    assertEq(dai.balanceOf(lsdTripper), lsdTripperOriginalDAIBalance + expectedWithdrawAmount);

    // assertEq(lsdai.sharesOf(lsdTripper), lsdai.getSharesByPooledDai(lsdTripperInitialDeposit - expectedSharesToBurn));
    // Fee receipient shares increased
    assertTrue(lsdai.sharesOf(lsdai.feeRecipient()) > 0);
  }

  function test_UserCanMintLSDAIAtOneToOneRatio() public {
    // Deposit DAI from LSD tripper
    depositDAI(lsdTripper, lsdTripperInitialDeposit);

    assert(dai.balanceOf(lsdTripper) == 0);
    assert(lsdai.balanceOf(lsdTripper) == lsdTripperInitialDeposit); // since 1:1 ratio and we're in the same block

    logLSDAIMetrics(lsdai, "at week 1");

    vm.warp(block.timestamp + 52 weeks);

    lsdai.rebase();
    logLSDAIMetrics(lsdai, "at week 52");

    logLSDaiUserMetrics(lsdai, lsdTripper, "LSD Tripper");
    // Withdraw DAI from LSD tripper
    withdrawDAI(lsdTripper, lsdai.balanceOf(lsdTripper));
  }

  function test_lsdaiIsSolventAfterBankrun() public {
    // Deposit DAI from LSD tripper
    depositDAI(lsdTripper, lsdTripperInitialDeposit);
    depositDAI(lsdEnjoyer, lsdEnjoyerInitialDeposit);
    depositDAI(lsdDreamer, lsdDreamerInitialDeposit);

    logLSDAIMetrics(lsdai, "at week 1");

    // Warp to 52 weeks
    vm.warp(block.timestamp + 52 weeks);
    lsdai.rebase();

    logLSDAIMetrics(lsdai, "at week 52");

    // Withdraw from LSD tripper
    {
      uint256 lsdaiEnjoyerBalanceBeforeWithdraw = lsdai.balanceOf(lsdEnjoyer);
      uint256 lsdaiDreamerBalanceBeforeWithdraw = lsdai.balanceOf(lsdDreamer);
      uint256 feeRecipientBalanceBeforeWithdraw = lsdai.balanceOf(lsdai.feeRecipient());

      withdrawDAI(lsdTripper, lsdai.balanceOf(lsdTripper));
      // Rebase after withdraw
      vm.warp(block.timestamp + 2 minutes);
      lsdai.rebase();

      uint256 lsdaiEnjoyerBalanceAfterWithdraw = lsdai.balanceOf(lsdEnjoyer);
      uint256 lsdaiDreamerBalanceAfterWithdraw = lsdai.balanceOf(lsdDreamer);
      uint256 feeRecipientBalanceAfterWithdraw = lsdai.balanceOf(lsdai.feeRecipient());

      assertTrue(
        lsdaiEnjoyerBalanceAfterWithdraw >= lsdaiEnjoyerBalanceBeforeWithdraw,
        string.concat(
          "LSD Enjoyer should have same or more LSDai after LSD tripper withdraws. ",
          "Expected: ",
          Strings.toString(lsdaiEnjoyerBalanceBeforeWithdraw),
          " or more. Got:",
          Strings.toString(lsdaiEnjoyerBalanceAfterWithdraw)
        )
      );
      assertTrue(
        lsdaiDreamerBalanceAfterWithdraw >= lsdaiDreamerBalanceBeforeWithdraw,
        string.concat(
          "LSD Dreamer should have same or more LSDai after LSD tripper withdraws. ",
          "Expected: ",
          Strings.toString(lsdaiDreamerBalanceBeforeWithdraw),
          " or more. Got:",
          Strings.toString(lsdaiDreamerBalanceAfterWithdraw)
        )
      );
      assertTrue(
        feeRecipientBalanceAfterWithdraw >= feeRecipientBalanceBeforeWithdraw,
        string.concat(
          "LSDai Fee Recipient should have same or more LSDai after LSD tripper withdraws. ",
          "Expected: ",
          Strings.toString(feeRecipientBalanceBeforeWithdraw),
          " or more. Got:",
          Strings.toString(feeRecipientBalanceAfterWithdraw)
        )
      );
    }

    // Withdraw from LSD Enjoyer
    {
      uint256 lsdaiDreamerBalanceBeforeWithdraw = lsdai.balanceOf(lsdDreamer);
      uint256 feeRecipientBalanceBeforeWithdraw = lsdai.balanceOf(lsdai.feeRecipient());

      withdrawDAI(lsdEnjoyer, lsdai.balanceOf(lsdEnjoyer));
      // Rebase after withdraw
      vm.warp(block.timestamp + 2 minutes);
      lsdai.rebase();

      uint256 lsdaiDreamerBalanceAfterWithdraw = lsdai.balanceOf(lsdDreamer);
      uint256 feeRecipientBalanceAfterWithdraw = lsdai.balanceOf(lsdai.feeRecipient());

      assertTrue(
        lsdaiDreamerBalanceAfterWithdraw >= lsdaiDreamerBalanceBeforeWithdraw,
        string.concat(
          "LSD Dreamer should have same or more LSDai after LSD Enjoyer withdraws. ",
          "Expected: ",
          Strings.toString(lsdaiDreamerBalanceBeforeWithdraw),
          " or more. Got:",
          Strings.toString(lsdaiDreamerBalanceAfterWithdraw)
        )
      );
      assertTrue(
        feeRecipientBalanceAfterWithdraw >= feeRecipientBalanceBeforeWithdraw,
        string.concat(
          "LSDai Fee Recipient should have same or more LSDai after LSD Enjoyer withdraws. ",
          "Expected: ",
          Strings.toString(feeRecipientBalanceBeforeWithdraw),
          " or more. Got:",
          Strings.toString(feeRecipientBalanceAfterWithdraw)
        )
      );
    }

    // Withdraw from LSD Dreamer
    {
      uint256 feeRecipientBalanceBeforeWithdraw = lsdai.balanceOf(lsdai.feeRecipient());

      withdrawDAI(lsdDreamer, lsdai.balanceOf(lsdDreamer));
      vm.warp(block.timestamp + 2 minutes);
      lsdai.rebase();

      assertTrue(
        lsdai.balanceOf(lsdai.feeRecipient()) >= feeRecipientBalanceBeforeWithdraw,
        "LSDai Fee Recipient should have same or more LSDai after LSD Dreamer withdraws"
      );
    }

    logLSDAIMetrics(lsdai, "after everyone withdrew");
  }

  function test_UserCannotExceedTheirBalanceOnWithdrawal() public {
    depositDAI(lsdTripper, lsdTripperInitialDeposit);
    assertEq(lsdai.balanceOf(lsdTripper), lsdTripperInitialDeposit, "LSD tripper should have initial deposit");
    uint256 attemptToWithdrawByHacker = lsdai.balanceOf(lsdTripper) - 10 ether;
    vm.startPrank(lsdEnjoyer);
    vm.expectRevert(LSDai.LSDai__AmountExceedsBalance.selector);
    lsdai.withdraw(attemptToWithdrawByHacker);
  }

  function test_userDAIAmountRoundownOnWithdrawals() public {
    uint256 initialDeposit = dai.balanceOf(lsdTripper);
    // Deposit everything into LSDai
    depositDAI(lsdTripper, initialDeposit);
    assertEq(dai.balanceOf(lsdTripper), 0, "LSD tripper should have 0 DAI");
    // 1:1 ratio
    assertEq(lsdai.balanceOf(lsdTripper), initialDeposit, "LSD tripper should have initial deposit");

    vm.warp(block.timestamp + 52 weeks);
    lsdai.rebase();

    uint256 daiAmountToWithdraw = lsdai.balanceOf(lsdTripper);
    vm.startPrank(lsdTripper);
    lsdai.withdraw(daiAmountToWithdraw);

    emit log_named_uint("DAI balance", dai.balanceOf(lsdTripper));
    emit log_named_uint("LSDai balance", lsdai.balanceOf(lsdTripper));
  }

  function test_UserCanWithdrawRecievedLSDAI() public {
    uint256 initialDeposit = dai.balanceOf(lsdTripper);
    // Deposit everything into LSDai
    depositDAI(lsdTripper, initialDeposit);
    assertEq(dai.balanceOf(lsdTripper), 0, "LSD tripper should have 0 DAI");
    // 1:1 ratio
    assertEq(lsdai.balanceOf(lsdTripper), initialDeposit, "LSD tripper should have initial deposit");
    assertEq(lsdai.balanceOf(lsdEnjoyer), 0, "LSD Enjoyer should have 0 LSDai");

    vm.warp(block.timestamp + 52 weeks);
    lsdai.rebase();

    // Take 1000 LSDAI from LSD tripper and give it to LSD Enjoyer
    uint256 amountToTransfer = 1000 ether;
    vm.prank(lsdTripper);
    lsdai.transfer(lsdEnjoyer, amountToTransfer);
    // assertEq(lsdai.balanceOf(lsdEnjoyer), amountToTransfer, 'LSD Enjoyer should have 1000 LSDai');

    // LSD enjoyer withdraws 1000 LSDai
    withdrawDAI(lsdEnjoyer, lsdai.balanceOf(lsdEnjoyer));
  }

  function test_depositCapEnforced() public {
    // Set deposit cap to 100 DAI
    lsdai.setDepositCap(100 ether);
    assertEq(lsdai.depositCap(), 100 ether, "Deposit cap should be 100 DAI");

    uint256 currentDepositCap = lsdai.depositCap();
    // Use the entire deposit cap by depositing the max amount
    depositDAI(lsdTripper, currentDepositCap);
    vm.warp(block.timestamp + 1 weeks);

    // Deposit 1 more DAI than the deposit cap
    uint256 depositAmount = currentDepositCap + 1;
    vm.prank(lsdTripper);
    vm.expectRevert(LSDai.LSDai__DepositCap.selector);
    lsdai.deposit({daiAmount: depositAmount, to: lsdTripper});
  }

  function test_feeRecipient() public {
    assertEq(lsdai.feeRecipient(), address(this), "Fee recipient should be this contract");
    // Set fee recipient to lsdTripper
    lsdai.setFeeRecipient(lsdTripper);
    assertEq(lsdai.feeRecipient(), lsdTripper, "Fee recipient should be lsdTripper");
    // Set fee recipient to lsdEnjoyer
    lsdai.setFeeRecipient(lsdEnjoyer);
    assertEq(lsdai.feeRecipient(), lsdEnjoyer, "Fee recipient should be lsdEnjoyer");
    // Set fee recipient to lsdDreamer
    lsdai.setFeeRecipient(lsdDreamer);
    assertEq(lsdai.feeRecipient(), lsdDreamer, "Fee recipient should be lsdDreamer");
  }

  function test_setWithdrawalFee() public {
    // Set withdrawal fee to 0.03%
    lsdai.setWithdrawalFee(3);
    assertEq(lsdai.withdrawalFee(), 3, 'Withdrawal fee should be 0.03%');
    // Revert if the fee is greater than 0.05%
    vm.expectRevert(LSDai.LSDai__WithdrawalFeeHigh.selector);
    lsdai.setWithdrawalFee(6);
  }

  function test_setInterestFee() public {
    // Set interest fee to 1%
    lsdai.setInterestFee(100);
    assertEq(lsdai.interestFee(), 100, 'Interest fee should be 1%');
    // Set interest fee to 3%
    lsdai.setInterestFee(300);
    assertEq(lsdai.interestFee(), 300, 'Interest fee should be 3%');
    // Revert on interest fee greater than 5%
    vm.expectRevert(LSDai.LSDai__InterestFeeHigh.selector);
    lsdai.setInterestFee(501);
  }

  function test_collectFees() public {
    address prevFeeRecipient = lsdai.feeRecipient();
    address feeRecipient = address(0x123);

    // Set fee recipient to feeRecipient
    assertEq(dai.balanceOf(prevFeeRecipient), 0, "Fee recipient should have 0 DAI");
    assertEq(dai.balanceOf(feeRecipient), 0, "Fee recipient should have 0 DAI");

    // Update fee recipient
    lsdai.setFeeRecipient(feeRecipient);

    assertEq(lsdai.feeRecipient(), feeRecipient, "Fee recipient should be feeRecipient");

    // deposit for lsdTripper
    depositDAI(lsdTripper, lsdTripperInitialDeposit);

    // Warp and rebase
    vm.warp(block.timestamp + 52 weeks);
    vm.prank(lsdai.owner()); // owner can rebase
    lsdai.rebase();

    // Expected DAI balance of fee recipient after collecting fees
    uint256 expectedDAIBalance = lsdai.balanceOf(feeRecipient);

    lsdai.collectFees();

    assertApproxEqAbs(dai.balanceOf(feeRecipient), expectedDAIBalance, 1 ether);
  }

  function depositDAI(address account, uint256 daiAmount) public {
    vm.startPrank(account);
    // maximum allowance
    dai.approve(address(lsdai), type(uint256).max);
    lsdai.deposit({daiAmount: daiAmount, to: account});
    vm.stopPrank();
  }

  function withdrawDAI(address account, uint256 daiAmount) public {
    vm.startPrank(account);
    lsdai.withdraw(daiAmount);
    vm.stopPrank();
  }
}

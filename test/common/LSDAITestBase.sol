// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {IDai} from "../../contracts/interfaces/IDai.sol";
import {LSDai} from "../../contracts/LSDai.sol";

address constant DAI_ADDRESS = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
address constant MAKER_POT = address(0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7);

/// @dev The MakerDAO DSR is stored in the 3rd storage slot of the Pot contract.
uint256 constant MAKER_POT_DSR_SLOT = 3;

contract TestUtils {
  function formatWei(uint256 _wei) public pure returns (uint256) {
    return _wei / 10 ** 18;
  }
}

contract LSDAITestBase is Test, TestUtils {
  /// @dev DAI token
  IDai dai = IDai(DAI_ADDRESS);

  /**
   * @dev Mint DAI to an address.
   */
  function mintDAI(address _to, uint256 _amount) public {
    deal({token: DAI_ADDRESS, to: _to, give: _amount, adjust: true});
  }

  /**
   * @dev Get the DSR for the MakerDAO Pot, direclty on the storage slot. Value is in RAY.
   */
  function getMakerDaiSavingsRate() public returns (uint256) {
    bytes32 dsr = vm.load(address(MAKER_POT), bytes32(uint256(MAKER_POT_DSR_SLOT)));
    emit log_named_uint("MakerDAO Dai Savings Rate", uint256(dsr));

    return uint256(dsr);
  }

  function depositDAI(LSDai lsdai, address account, uint256 daiAmount) public {
    vm.startPrank(account);
    // maximum allowance
    dai.approve(address(lsdai), type(uint256).max);
    lsdai.deposit({daiAmount: daiAmount, to: account});
    vm.stopPrank();
  }

  function withdrawDAI(LSDai lsdai, address account, uint256 daiAmount) public {
    vm.startPrank(account);
    lsdai.withdraw(daiAmount);
    vm.stopPrank();
  }

  /**
   * @dev Log LSDai metrics.
   */
  function logLSDAIMetrics(LSDai lsdai, string memory _header) public {
    string memory header = bytes(_header).length > 0 ? string.concat(" ", _header, " ") : "";

    emit log_string(string.concat("------- LSDai Metrics", header, "-------"));
    emit log_named_decimal_uint("LSDAI total supply", lsdai.totalSupply(), 18);
    emit log_named_decimal_uint("LSDAI protcol fees (fee feeRecipient)", lsdai.balanceOf(lsdai.feeRecipient()), 18);
    emit log_named_decimal_uint("LSDAI total supply according to DSR", lsdai.getTotalPotSharesValue(), 18);
    emit log_named_decimal_uint("LSDAI pot shares using pot.pie()", lsdai.potShares(), 18);
    emit log_string("");
    emit log_string("");
  }

  /**
   * @dev Log LSDai user metrics.
   */
  function logLSDaiUserMetrics(LSDai lsdai, address account, string memory accountName) public {
    uint256 balance = lsdai.balanceOf(account);
    uint256 shares = lsdai.sharesOf(account);

    // Logging
    emit log_string(string.concat("------- ", accountName, " Metrics -------"));
    emit log_named_decimal_uint(string.concat(accountName, " LSDAI balance"), balance, 18);
    emit log_named_decimal_uint(string.concat(accountName, " LSDAI shares"), shares, 18);
    // emit log_named_decimal_uint('balance shares', lsdai.getSharesByPooledDai(balance), 18);
    emit log_named_decimal_uint(string.concat(accountName, " DAI balance"), dai.balanceOf(account), 18);

    emit log_string("");
    emit log_string("");
  }
}

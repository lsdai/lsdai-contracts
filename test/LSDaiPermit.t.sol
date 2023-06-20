// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {LSDAITestBase, MAKER_POT} from "./common/LSDAITestBase.sol";
import {LSDai} from "../contracts/LSDai.sol";
import {IDai} from "../contracts/interfaces/IDai.sol";

address constant DAI_ADDRESS = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

contract LSDaiPermitTests is LSDAITestBase {
  using SafeMath for uint256;
  // Test events

  LSDai lsdai;

  uint256 constant DEPOSITOR_PRIVATE_KEY = 420;
  address depositor;

  function setUp() public {
    depositor = vm.addr(DEPOSITOR_PRIVATE_KEY);

    lsdai = new LSDai();
    // initialize LSDai
    lsdai.initialize(
      150_000_000 ether, // 150M DAI deposit cap
      250, // 0.25% interest fee
      1, // 0.01% withdrawal fee
      address(this) // fee recipient
    );
  }

  function test_depositWithPermit() public {
    uint256 daiAmount = 100 ether;

    mintDAI(depositor, daiAmount);

    uint256 permitNonce = dai.nonces(depositor);
    uint256 permitExpiry = block.timestamp + 1000;
    // approve LSDai to spend depositor's DAI
    // Sender - prepare permit signature
    bytes32 permitHash = _getPermitHash(
      depositor, // holder
      address(lsdai), // spender
      permitNonce, // nonce
      permitExpiry, // expiry
      true
    );
    (uint8 permitV, bytes32 permitR, bytes32 permitS) = vm.sign(DEPOSITOR_PRIVATE_KEY, permitHash);
    vm.prank(depositor);
    lsdai.depositWithPermit(depositor, daiAmount, permitNonce, permitExpiry, permitV, permitR, permitS);
    assertEq(lsdai.balanceOf(depositor), daiAmount);
  }

  function _getPermitHash(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed)
    private
    view
    returns (bytes32)
  {
    return keccak256(
      abi.encodePacked(
        "\x19\x01",
        dai.DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)"),
            holder,
            spender,
            nonce,
            expiry,
            allowed
          )
        )
      )
    );
  }
}

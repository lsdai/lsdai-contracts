// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPot {
  function chi() external view returns (uint256);

  function rho() external view returns (uint256);

  function dsr() external view returns (uint256);

  function drip() external returns (uint256);

  function join(uint256) external;

  function exit(uint256) external;

  /**
   * @notice Return the balance of a given address in this contract. Normalised Savings Dai [wad]
   */
  function pie(address) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISavingsVault {
    function deposit(uint256 amount) external;
    function redeem(uint256 tokenId) external;
    function previewRedeem(uint256 tokenId) external view returns (uint256 principal, uint256 fee, uint256 payout);
}

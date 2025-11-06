// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// interface for SavingsV   
// function yg ada disini sesuai dg yg diimplement di SavingVault.sol
// apabila ada function baru di SavingsVault.sol harus ditambah di interface ini.
interface ISavingsVault {
    function deposit(uint256 amount) external;                                                                          // untuk deposit MFI ke vault
    function redeem(uint256 tokenId) external;                                                                          // untuk redeem NFT dan menerima MFI
    function previewRedeem(uint256 tokenId) external view returns (uint256 principal, uint256 fee, uint256 payout);     // perkiraan jumlah MFI yg diterima saat redeem
    function getUserDeposits(address user) external view returns (uint256[] memory);                                    // mendapatkan array token IDs yg dimiliki user
}

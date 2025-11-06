// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// interface for SavingsNFT
// function yg ada disini sesuai dg yg diimplement di SavingsNFT.sol
// apabila ada function baru di SavingsNFT.sol harus ditambah di interface ini.
interface ISavingsNFT {
    function mint(address to, uint8 initialRoses) external returns (uint256 tokenId);       // untuk membuat NFT baru.
    function upgrade(uint256 tokenId, uint8 addRoses) external;                             // meng-upgrade jumlah mawar di NFT yg sudah ada.
    function burn(uint256 tokenId) external;                                                // menghancur NFT saat redeem.
    
    function balanceOf(address owner) external view returns (uint256);                      // jumlah NFT yg dimiliki owner
    function ownerOf(uint256 tokenId) external view returns (address);                      // pemilik NFT berdasarkan tokenId
    function roseCountOf(uint256 tokenId) external view returns (uint8);                    // jumlah mawar di NFT berdasarkan tokenId
    function isFull(uint256 tokenId) external view returns (bool);                          // apakah NFT sudah penuh (10 mawar) 
}

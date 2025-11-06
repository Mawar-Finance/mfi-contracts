// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISavingsNFT {
    function mint(address to, uint8 initialRoses) external returns (uint256 tokenId);
    function upgrade(uint256 tokenId, uint8 addRoses) external;
    function burn(uint256 tokenId) external;

    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function roseCountOf(uint256 tokenId) external view returns (uint8);
    function isFull(uint256 tokenId) external view returns (bool);
}

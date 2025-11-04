// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MFI Token (fixed supply)
/// @notice Total supply dicetak ke deployer saat kontrak dibuat. Tidak ada mint/burn lanjutan.
contract MFI is ERC20 {
    /// @param initialSupply jumlah awal (18 desimal) akan dikirim ke deployer
    constructor(uint256 initialSupply) ERC20("Mawar Finance Token", "MFI") {
        _mint(msg.sender, initialSupply);
    }
}

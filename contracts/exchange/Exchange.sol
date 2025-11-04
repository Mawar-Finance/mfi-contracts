// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IMFI.sol";
import "../libs/Errors.sol";

/// @title Exchange - Beli MFI pakai ETH (kurs tetap, immutable)
/// @dev Kontrak ini TIDAK mencetak MFI. Ia hanya menjual dari stok MFI yang dimilikinya.
///      Pastikan kamu transfer MFI ke alamat kontrak ini sebagai "liquidity".
contract Exchange {
    IMFI public immutable mfi;

    /// @notice MFI per 1 ETH (18 desimal). Contoh: 3000e18 = 3000 MFI/ETH.
    uint256 public immutable rate;

    event Purchased(address indexed buyer, uint256 ethIn, uint256 mfiOut);

    /// @param _mfi alamat token MFI
    /// @param _rate MFI per 1 ETH (18 desimal); contoh 3000e18
    constructor(IMFI _mfi, uint256 _rate) {
        if (address(_mfi) == address(0)) revert Errors.ZeroAddress();
        if (_rate == 0) revert Errors.InvalidAmount();
        mfi = _mfi;
        rate = _rate;
    }

    /// @notice Beli MFI pakai ETH dengan kurs tetap; MFI dikirim dari stok kontrak ini.
    function buyMFI(address to) public payable {
        if (to == address(0)) revert Errors.ZeroAddress();
        if (msg.value == 0) revert Errors.InvalidAmount();

        uint256 mfiOut = (msg.value * rate) / 1e18;

        // Pastikan stok cukup
        uint256 bal = mfi.balanceOf(address(this));
        require(bal >= mfiOut, "Exchange: insufficient MFI liquidity");

        bool ok = mfi.transfer(to, mfiOut);
        require(ok, "Exchange: MFI transfer failed");

        emit Purchased(to, msg.value, mfiOut);
    }

    /// @notice Kirim ETH langsung → auto beli untuk pengirim
    receive() external payable {
        buyMFI(msg.sender);
    }
}

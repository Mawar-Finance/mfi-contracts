// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24; // Versi compiler Solidity yang digunakan

// Import interface token MFI (mirip ERC20 tapi disesuaikan)
import "../interfaces/IMFI.sol";

// Import library custom untuk error handling
import "../libs/Errors.sol";

/// @title Exchange - Beli MFI pakai ETH (kurs tetap, immutable)
/// @dev Kontrak ini hanya MENJUAL token MFI dari stok yang dimilikinya (bukan mencetak token baru)
///      Artinya, pemilik kontrak harus lebih dulu mengirim sejumlah MFI ke kontrak ini agar bisa dijual.
contract Exchange {
    // Deklarasi variabel `mfi` bertipe interface IMFI, immutable artinya tidak bisa diubah setelah deploy
    IMFI public immutable mfi;

    /// @notice Nilai tukar MFI per 1 ETH, menggunakan 18 desimal (contoh: 3000e18 berarti 3000 MFI per 1 ETH)
    uint256 public immutable rate;

    // Event untuk mencatat setiap pembelian MFI (siapa pembeli, berapa ETH masuk, berapa MFI keluar)
    event Purchased(address indexed buyer, uint256 ethIn, uint256 mfiOut);

    /// @param _mfi Alamat kontrak token MFI
    /// @param _rate Nilai tukar MFI per 1 ETH (dalam 18 desimal)
    constructor(IMFI _mfi, uint256 _rate) {
        // Validasi: alamat token MFI tidak boleh nol
        if (address(_mfi) == address(0)) revert Errors.ZeroAddress();

        // Validasi: rate tidak boleh 0
        if (_rate == 0) revert Errors.InvalidAmount();

        // Set nilai mfi dan rate yang bersifat tetap (immutable)
        mfi = _mfi;
        rate = _rate;
    }

    /// @notice Fungsi utama untuk membeli MFI dengan ETH berdasarkan kurs tetap
    /// @param to Alamat penerima token MFI hasil pembelian
    function buyMFI(address to) public payable {
        // Pastikan alamat tujuan tidak kosong
        if (to == address(0)) revert Errors.ZeroAddress();

        // Pastikan jumlah ETH yang dikirim tidak nol
        if (msg.value == 0) revert Errors.InvalidAmount();

        // Hitung jumlah MFI yang harus diberikan ke pembeli
        // Rumus: ETH * rate / 1e18 (karena 18 desimal)
        uint256 mfiOut = (msg.value * rate) / 1e18;

        // Ambil saldo MFI yang dimiliki kontrak ini (stok likuiditas)
        uint256 bal = mfi.balanceOf(address(this));

        // Pastikan stok MFI cukup untuk dibeli
        require(bal >= mfiOut, "Exchange: insufficient MFI liquidity");

        // Transfer MFI dari kontrak ini ke alamat pembeli
        bool ok = mfi.transfer(to, mfiOut);

        // Pastikan transfer berhasil
        require(ok, "Exchange: MFI transfer failed");

        // Emit event pembelian berhasil
        emit Purchased(to, msg.value, mfiOut);
    }

    /// @notice Fungsi fallback: kalau user kirim ETH langsung ke kontrak tanpa panggil fungsi apa pun,
    ///         otomatis akan dianggap beli MFI dan token dikirim ke pengirim
    receive() external payable {
        buyMFI(msg.sender);
    }
}

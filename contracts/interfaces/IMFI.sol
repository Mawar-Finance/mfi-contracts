// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IMFI (Minimal ERC20 Interface)
/// @notice Antarmuka minimal token MFI yang dipakai di project (tanpa fungsi mint/burn)
/// @dev Hanya expose fungsi yang dibutuhkan Vault/Frontend: decimals, balanceOf, transfer, transferFrom
interface IMFI {
    /// @notice Jumlah desimal yang dipakai token (contoh: 18)
    /// @dev Berguna buat konversi UI (mis. 1 MFI = 10**decimals)
    /// @return uint8 Banyaknya desimal
    function decimals() external view returns (uint8);

    /// @notice Cek saldo MFI milik `account`
    /// @param account Alamat yang dicek saldonya
    /// @return uint256 Saldo dalam satuan paling kecil (wei-nya token)
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfer MFI dari caller (msg.sender) ke `to`
    /// @dev Mengembalikan true kalau sukses; biasanya revert kalau gagal
    /// @param to Penerima token
    /// @param amount Jumlah token (dalam satuan paling kecil)
    /// @return bool Status sukses transfer
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Transfer MFI dari `from` ke `to` menggunakan allowance
    /// @dev Butuh `approve` sebelumnya dari `from` ke caller minimal sebesar `amount`
    /// @param from Pemilik token yang di-debit
    /// @param to Penerima token
    /// @param amount Jumlah token (dalam satuan paling kecil)
    /// @return bool Status sukses transfer
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

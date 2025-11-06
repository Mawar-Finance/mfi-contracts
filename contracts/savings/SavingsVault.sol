// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;                            // Versi Solidity

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";   // Cegah serangan reentrancy
import "../interfaces/IMFI.sol";                                  // Interface token MFI (ERC20)
import "../interfaces/ISavingsNFT.sol";                           // Interface NFT tabungan
import "../libs/Errors.sol";                                      // Custom error collection

/// @title SavingsVault - Nabung & Redeem (tanpa admin/role)
/// @dev Semua parameter penting dikunci saat deploy (immutable).
contract SavingsVault is ReentrancyGuard {
    IMFI public immutable mfi;                     // Token MFI, immutable artinya tidak bisa diubah
    ISavingsNFT public immutable nft;              // NFT bunga mawar
    uint16 public immutable feeBps;                // Fee platform dalam basis poin (bps)
    address public immutable treasury;             // Alamat penerima fee platform

    uint256 public constant ROSE_UNIT = 10 * 1e18; // 1 mawar = 10 MFI

    mapping(address => uint256) public activeBucketId; // Simpan tokenId buket aktif tiap user

    mapping(address => uint256[]) private userDeposits; // List semua NFT (buket) milik user
    mapping(uint256 => uint256) private depositIndex;   // Posisi tokenId dalam array userDeposits[user]

    event Deposited(address indexed user, uint256 amountMFI, uint256 rosesAdded);  // Event deposit
    event NFTMinted(address indexed user, uint256 indexed tokenId, uint8 roseCount); // Event mint NFT baru
    event NFTUpgraded(address indexed user, uint256 indexed tokenId, uint8 oldCount, uint8 newCount); // Event upgrade NFT
    event Redeemed(address indexed user, uint256 indexed tokenId, uint256 principal, uint256 fee, uint256 payout); // Event redeem

    constructor(IMFI _mfi, ISavingsNFT _nft, address _treasury, uint16 _feeBps) {
        if (address(_mfi) == address(0) || address(_nft) == address(0) || _treasury == address(0)) {
            revert Errors.ZeroAddress();            // Cegah alamat kosong
        }
        mfi = _mfi;                                // Set alamat kontrak MFI
        nft = _nft;                                // Set alamat kontrak NFT
        treasury = _treasury;                      // Set penerima fee
        feeBps = _feeBps;                          // Set fee (dalam bps)
    }

    /// @notice Deposit MFI kelipatan 10 → upgrade/mint buket
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert Errors.InvalidAmount();         // Cegah deposit nol
        if (amount % ROSE_UNIT != 0) revert Errors.NotMultipleOfRoseUnit(); // Harus kelipatan 10 MFI

        bool ok = mfi.transferFrom(msg.sender, address(this), amount);      // Transfer MFI dari user ke vault
        require(ok, "MFI transferFrom failed");                             // Pastikan berhasil

        uint256 rosesToAdd = amount / ROSE_UNIT;                            // Hitung berapa mawar yang ditambah
        emit Deposited(msg.sender, amount, rosesToAdd);                     // Log event

        uint256 tokenId = activeBucketId[msg.sender];                       // Ambil NFT aktif user (0 kalau belum ada)

        while (rosesToAdd > 0) {                                            // Selama masih ada mawar tersisa buat ditambah
            if (tokenId == 0) {                                             // Kalau user belum punya buket aktif
                uint8 initial = uint8(rosesToAdd > 10 ? 10 : rosesToAdd);   // Ambil max 10 mawar
                tokenId = nft.mint(msg.sender, initial);                    // Mint NFT baru
                activeBucketId[msg.sender] = tokenId;                       // Set NFT ini jadi aktif
                userDeposits[msg.sender].push(tokenId);                     // Simpan ke daftar milik user
                depositIndex[tokenId] = userDeposits[msg.sender].length;    // Simpan index+1 buat tracking
                emit NFTMinted(msg.sender, tokenId, initial);               // Log mint event
                rosesToAdd -= initial;                                      // Kurangi mawar yang udah dipakai
                if (initial == 10) tokenId = 0;                             // Kalau sudah penuh, reset untuk loop berikutnya
            } else {                                                        // Kalau user punya NFT aktif
                uint8 current = nft.roseCountOf(tokenId);                   // Ambil jumlah mawar sekarang
                if (current == 10) {                                        // Kalau sudah penuh, reset ke 0
                    activeBucketId[msg.sender] = 0;
                    tokenId = 0;
                    continue;                                               // Lanjut ke loop berikutnya
                }
                uint8 canAdd = uint8(10 - current);                             // Hitung berapa mawar bisa ditambah
                uint8 add = uint8(rosesToAdd > canAdd ? canAdd : rosesToAdd);   // Pilih jumlah yang bisa
                nft.upgrade(tokenId, add);                                      // Upgrade NFT dengan tambahan mawar
                emit NFTUpgraded(msg.sender, tokenId, current, current + add);  // Log event
                rosesToAdd -= add;                                              // Kurangi sisa mawar
                if (current + add == 10) {                                      // Kalau sudah penuh
                    activeBucketId[msg.sender] = 0;                             // Reset NFT aktif
                    tokenId = 0;
                }
            }
        }
    }

    /// @notice Redeem penuh 1 NFT → burn & kirim MFI (principal-fee)
    function redeem(uint256 tokenId) external nonReentrant {
        if (nft.ownerOf(tokenId) != msg.sender) revert Errors.NotTokenOwner();          // Pastikan pemilik sah

        (uint256 principal, uint256 fee, uint256 payout) = previewRedeem(tokenId);      // Hitung nilai redeem

        nft.burn(tokenId);                                                              // Burn NFT
        if (activeBucketId[msg.sender] == tokenId) activeBucketId[msg.sender] = 0;      // Reset jika aktif

        uint256 idxPlusOne = depositIndex[tokenId];                                     // Ambil index token di array userDeposits
        if (idxPlusOne > 0) {                                                           // Jika ditemukan
            uint256 idx = idxPlusOne - 1;
            uint256 lastIdx = userDeposits[msg.sender].length - 1;

            if (idx != lastIdx) {                                                       // Jika bukan elemen terakhir
                uint256 lastToken = userDeposits[msg.sender][lastIdx];                  // Ambil token terakhir
                userDeposits[msg.sender][idx] = lastToken;                              // Ganti posisi
                depositIndex[lastToken] = idx + 1;                                      // Update index baru
            }
            userDeposits[msg.sender].pop();                                             // Hapus elemen terakhir
            depositIndex[tokenId] = 0;                                                  // Hapus index token ini
        }

        if (fee > 0) {                                                                  // Jika ada fee
            bool okFee = mfi.transfer(treasury, fee);                                   // Kirim fee ke treasury
            require(okFee, "MFI fee transfer failed");
        }

        bool okUser = mfi.transfer(msg.sender, payout);                                 // Kirim sisa (principal-fee) ke user
        require(okUser, "MFI payout transfer failed");

        emit Redeemed(msg.sender, tokenId, principal, fee, payout);                     // Log redeem
    }

    /// @notice Simulasi hitung nilai redeem
    function previewRedeem(uint256 tokenId)
        public
        view
        returns (uint256 principal, uint256 fee, uint256 payout)
    {
        uint8 roses = nft.roseCountOf(tokenId);          // Ambil jumlah mawar di NFT
        principal = uint256(roses) * ROSE_UNIT;          // Total MFI sesuai jumlah mawar
        fee = (principal * feeBps) / 10_000;             // Hitung fee berdasarkan bps
        payout = principal - fee;                        // Nilai bersih user
    }

    /// @notice Get semua token IDs yang dimiliki user
    /// @param user Alamat user yang dicari depositnya
    /// @return Array dari token IDs yang dimiliki user
    function getUserDeposits(address user) external view returns (uint256[] memory) {
        if (user == address(0)) {
            return new uint256[](0);
        }
        // Empty array if no deposits yet
        if (userDeposits[user].length == 0) {
            return new uint256[](0);
        }
        return userDeposits[user];
    }
    /**
     * @notice Dipanggil otomatis oleh NFT contract setiap kali ada transfer antar user (via callback)
     * @param from Alamat pemilik lama
     * @param to Alamat pemilik baru
     * @param tokenId ID NFT yang dipindahkan
     */
    function onNftTransfer(address from, address to, uint256 tokenId) external /* nonReentrant opsional */ {
        // Hanya izinkan pemanggilan dari kontrak NFT resmi (biar gak bisa diserang kontrak luar)
        require(msg.sender == address(nft), "only nft");

        // =====================================================
        // ========== HAPUS tokenId dari pemilik lama ==========
        // =====================================================

        // Ambil posisi (index+1) token di array userDeposits[from]
        uint256 idxPlusOne = depositIndex[tokenId];

        // Kalau token tersebut memang terdaftar di list userDeposits[from]
        if (idxPlusOne > 0) {
            // Kurangi 1 untuk dapetin index aslinya
            uint256 idx = idxPlusOne - 1;

            // Ambil index terakhir di array pemilik lama
            uint256 lastIdx = userDeposits[from].length - 1;

            // Jika token yang mau dihapus bukan elemen terakhir di array
            if (idx != lastIdx) {
                // Ambil token terakhir di array untuk swap
                uint256 lastToken = userDeposits[from][lastIdx];

                // Gantikan posisi token yang dihapus dengan token terakhir
                userDeposits[from][idx] = lastToken;

                // Update depositIndex untuk token yang ditukar posisinya
                depositIndex[lastToken] = idx + 1;
            }

            // Hapus elemen terakhir (pop) karena sudah disalin ke posisi idx
            userDeposits[from].pop();

            // Reset index tokenId yang sudah dipindahkan ke 0 (tidak terdaftar di from lagi)
            depositIndex[tokenId] = 0;
        }

        // =====================================================
        // ===== TAMBAH tokenId ke pemilik baru (user to) ======
        // =====================================================

        // Tambahkan tokenId ke array milik pemilik baru
        userDeposits[to].push(tokenId);

        // Simpan posisi baru tokenId di array pemilik baru (index+1)
        depositIndex[tokenId] = userDeposits[to].length;

        // =====================================================
        // ========== RESET buket aktif kalau perlu ============
        // =====================================================

        // Jika token yang dipindahkan adalah buket aktif si pemilik lama,
        // maka reset activeBucketId[from] ke 0 (karena udah pindah tangan)
        if (activeBucketId[from] == tokenId) {
            activeBucketId[from] = 0;
        }
    }

}

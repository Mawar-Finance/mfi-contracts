// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../libs/Errors.sol";

/// @title SavingsNFT - Buket Mawar (ERC721)
/// @dev Vault ditetapkan sekali melalui setVaultOnce oleh deployer NFT, setelah itu permanen.
contract SavingsNFT is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _ids;

    /// @notice alamat Vault yang berwenang mint/upgrade/burn
    address public vault;

    /// @notice alamat deployer NFT yang boleh memanggil setVaultOnce
    address public immutable initializer;

    /// @dev roseCount per tokenId (1..10)
    /// HashMap menyimpan jumlah mawar tiap NFT
    mapping(uint256 => uint8) private _roseCount;

    uint8 public constant MAX_ROSES = 10;

    event VaultSet(address indexed vault);
    event Minted(address indexed to, uint256 indexed tokenId, uint8 initialRoses);
    event Upgraded(uint256 indexed tokenId, uint8 oldCount, uint8 newCount);
    event Burned(uint256 indexed tokenId);

    constructor() ERC721("Mawar Savings Buket", "MSB") {
        initializer = msg.sender;
    }

    /// @notice Set vault sekali saja (hanya deployer NFT, dan hanya sekali)
    function setVaultOnce(address newVault) external {
        if (msg.sender != initializer) revert Errors.Unauthorized();
        if (newVault == address(0)) revert Errors.ZeroAddress();
        if (vault != address(0)) revert Errors.Unauthorized(); // sudah pernah di-set
        vault = newVault;
        emit VaultSet(newVault);
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert Errors.Unauthorized();
        _;
    }

    /// @notice Mint NFT baru ke `to` dengan `initialRoses` (1..10). Hanya Vault.
    function mint(address to, uint8 initialRoses) external onlyVault returns (uint256 tokenId) {
        // Validasi: kalau alamat tujuan kosong (0x0), transaksi dibatalkan.
        if (to == address(0)) revert Errors.ZeroAddress();

        // Validasi: initialRoses harus antara 1 dan MAX_ROSES
        if (initialRoses == 0 || initialRoses > MAX_ROSES) revert Errors.ExceedsMaxRoses();

        _ids.increment();                       // Menambah counter ID token untuk membuat ID unik bagi NFT baru.
        tokenId = _ids.current();               // Mendapatkan ID token saat ini dari counter.
        _safeMint(to, tokenId);                 // Mint NFT baru dengan ID token yang dihasilkan ke alamat `to`.
        _roseCount[tokenId] = initialRoses;     // Menetapkan jumlah mawar awal untuk NFT yang baru dibuat.

        emit Minted(to, tokenId, initialRoses); // Mencatat event minting NFT baru.
    }

    /// @notice Upgrade jumlah mawar (tambah) hingga maksimum 10. Hanya Vault.
    function upgrade(uint256 tokenId, uint8 addRoses) external onlyVault {
        if (addRoses == 0) revert Errors.InvalidAmount();
        uint8 oldCount = _roseCount[tokenId];
        uint256 newCount = uint256(oldCount) + uint256(addRoses);
        if (newCount > MAX_ROSES) revert Errors.ExceedsMaxRoses();

        _roseCount[tokenId] = uint8(newCount);
        emit Upgraded(tokenId, oldCount, uint8(newCount));
    }

    /// @notice Burn NFT (hapus buket). Hanya Vault.
    function burn(uint256 tokenId) external onlyVault {
        _burn(tokenId);
        delete _roseCount[tokenId];
        emit Burned(tokenId);
    }

    /// @notice Lihat roseCount suatu NFT
    function roseCountOf(uint256 tokenId) external view returns (uint8) {
        return _roseCount[tokenId];
    }

    /// @notice True jika NFT sudah penuh (10 mawar)
    function isFull(uint256 tokenId) external view returns (bool) {
        return _roseCount[tokenId] == MAX_ROSES;
    }

    /// (Opsional) Metadata base URI (ganti sesuai UI kamu)
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://metadata-mawar/";
    }
}

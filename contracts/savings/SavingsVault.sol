// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IMFI.sol";
import "../interfaces/ISavingsNFT.sol";
import "../libs/Errors.sol";

/// @title SavingsVault - Nabung & Redeem (tanpa admin/role)
/// @dev Semua parameter kunci dikunci saat deploy (immutable).
contract SavingsVault is ReentrancyGuard {
    IMFI public immutable mfi;
    ISavingsNFT public immutable nft;

    /// @notice fee (bps) dikunci saat deploy. 250 = 2.5%
    uint16 public immutable feeBps;

    /// @notice alamat penerima fee (dikunci saat deploy)
    address public immutable treasury;

    /// @notice 1 mawar = 10 MFI (18 desimal)
    uint256 public constant ROSE_UNIT = 10 * 1e18;

    /// @dev buket aktif per user (0 jika tidak ada)
    mapping(address => uint256) public activeBucketId;

    /// @dev array token IDs yang dimiliki user
    mapping(address => uint256[]) private userDeposits;
    /// @dev index (plus one) dari tokenId di array userDeposits[user]
    mapping(uint256 => uint256) private depositIndex;

    event Deposited(address indexed user, uint256 amountMFI, uint256 rosesAdded);
    event NFTMinted(address indexed user, uint256 indexed tokenId, uint8 roseCount);
    event NFTUpgraded(address indexed user, uint256 indexed tokenId, uint8 oldCount, uint8 newCount);
    event Redeemed(address indexed user, uint256 indexed tokenId, uint256 principal, uint256 fee, uint256 payout);

    /// @param _mfi alamat token MFI
    /// @param _nft alamat SavingsNFT
    /// @param _treasury alamat penerima fee
    /// @param _feeBps fee dalam bps (misal 250 = 2.5%)
    constructor(IMFI _mfi, ISavingsNFT _nft, address _treasury, uint16 _feeBps) {
        if (address(_mfi) == address(0) || address(_nft) == address(0) || _treasury == address(0)) {
            revert Errors.ZeroAddress();
        }
        mfi = _mfi;
        nft = _nft;
        treasury = _treasury;
        feeBps = _feeBps;
    }

    /// @notice Deposit MFI kelipatan 10 → upgrade/mint buket
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert Errors.InvalidAmount();
        if (amount % ROSE_UNIT != 0) revert Errors.NotMultipleOfRoseUnit();

        // Tarik MFI dari user ke vault
        bool ok = mfi.transferFrom(msg.sender, address(this), amount);
        require(ok, "MFI transferFrom failed");

        uint256 rosesToAdd = amount / ROSE_UNIT;
        emit Deposited(msg.sender, amount, rosesToAdd);

        uint256 tokenId = activeBucketId[msg.sender];

        while (rosesToAdd > 0) {
            if (tokenId == 0) {
                // mint buket baru
                uint8 initial = uint8(rosesToAdd > 10 ? 10 : rosesToAdd);
                tokenId = nft.mint(msg.sender, initial);
                activeBucketId[msg.sender] = tokenId;
                // Track deposit
                userDeposits[msg.sender].push(tokenId);
                depositIndex[tokenId] = userDeposits[msg.sender].length; // store index+1
                emit NFTMinted(msg.sender, tokenId, initial);
                rosesToAdd -= initial;
                if (initial == 10) {
                    tokenId = 0; // penuh → siap mint baru di loop berikutnya
                }
            } else {
                // upgrade buket aktif
                uint8 current = nft.roseCountOf(tokenId);
                if (current == 10) {
                    activeBucketId[msg.sender] = 0;
                    tokenId = 0;
                    continue;
                }
                uint8 canAdd = uint8(10 - current);
                uint8 add = uint8(rosesToAdd > canAdd ? canAdd : rosesToAdd);
                nft.upgrade(tokenId, add);
                emit NFTUpgraded(msg.sender, tokenId, current, current + add);
                rosesToAdd -= add;
                if (current + add == 10) {
                    activeBucketId[msg.sender] = 0;
                    tokenId = 0;
                }
            }
        }
    }

    /// @notice Redeem penuh 1 NFT → burn & kirim MFI (principal-fee) ke user, fee ke treasury
    function redeem(uint256 tokenId) external nonReentrant {
        if (nft.ownerOf(tokenId) != msg.sender) revert Errors.NotTokenOwner();

        (uint256 principal, uint256 fee, uint256 payout) = previewRedeem(tokenId);

        // burn NFT
        nft.burn(tokenId);
        if (activeBucketId[msg.sender] == tokenId) {
            activeBucketId[msg.sender] = 0;
        }

        // Remove from userDeposits using swap-pop
        uint256 idxPlusOne = depositIndex[tokenId];
        if (idxPlusOne > 0) {
            uint256 idx = idxPlusOne - 1;
            uint256 lastIdx = userDeposits[msg.sender].length - 1;
            
            if (idx != lastIdx) {
                // Swap with last element
                uint256 lastToken = userDeposits[msg.sender][lastIdx];
                userDeposits[msg.sender][idx] = lastToken;
                depositIndex[lastToken] = idx + 1;
            }
            userDeposits[msg.sender].pop();
            depositIndex[tokenId] = 0;
        }

        // kirim fee ke treasury (jika > 0)
        if (fee > 0) {
            bool okFee = mfi.transfer(treasury, fee);
            require(okFee, "MFI fee transfer failed");
        }

        // kirim payout ke user
        bool okUser = mfi.transfer(msg.sender, payout);
        require(okUser, "MFI payout transfer failed");

        emit Redeemed(msg.sender, tokenId, principal, fee, payout);
    }

    /// @notice Simulasi hitung nilai redeem
    function previewRedeem(uint256 tokenId)
        public
        view
        returns (uint256 principal, uint256 fee, uint256 payout)
    {
        uint8 roses = nft.roseCountOf(tokenId);
        principal = uint256(roses) * ROSE_UNIT;
        fee = (principal * feeBps) / 10_000;
        payout = principal - fee;
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
}

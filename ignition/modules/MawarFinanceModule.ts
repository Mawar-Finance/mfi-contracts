import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MawarFinanceModule = buildModule("MawarFinanceModule", (m) => {
  // ===== Static values =====
  const TREASURY = "0x542bf9e46f15f534c8eaf58885663059359a8817"; // ganti ke wallet lu
  const FEE_BPS = 250;                        // 2.5% fee
  const INITIAL_SUPPLY = 1_000_000n * 10n**18n; // 1,000,000 MFI
  const RATE_MFI_PER_ETH = 300_000_000n * 10n**18n; // 300,000,000 MFI per ETH | 1 MFI = 0.00000001 ETH
  // const RATE_MFI_PER_ETH = 3000n * 10n**18n; // 3000 MFI per ETH
  const SEED_AMOUNT = 100_000n * 10n**18n;   // Transfer 100k MFI ke Exchange

  // ===== Deploy contracts =====

  // 1) MFI Token
  const mfi = m.contract("MFI", [INITIAL_SUPPLY]);

  // 2) NFT
  const nft = m.contract("SavingsNFT");

  // 3) Vault (mfi, nft, treasury, fee)
  const vault = m.contract("SavingsVault", [
    mfi,
    nft,
    TREASURY,
    FEE_BPS,
  ]);

  // After deploy → link NFT to Vault
  m.call(nft, "setVaultOnce", [vault]);

  // 4) Exchange (fixed rate)
  const exchange = m.contract("Exchange", [
    mfi,
    RATE_MFI_PER_ETH,
  ]);

  // Seed liquidity to Exchange
  m.call(mfi, "transfer", [exchange, SEED_AMOUNT]);

  return { mfi, nft, vault, exchange };
});

export default MawarFinanceModule;

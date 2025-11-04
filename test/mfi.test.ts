import { describe, it, before } from "node:test";
import { expect } from "chai";
import hre, { artifacts, network } from "hardhat";
import type { Abi } from "viem";
import { parseEther, parseUnits } from "viem";

/**
 * Exchange Rate Info:
 * 1 MFI = 0.0000001 ETH
 * berarti 10,000,000 MFI per 1 ETH
 * 
 * RATE di smart contract butuh scaling 1e18 (karena BigInt math)
 * makanya RATE = 10,000,000 * 1e18
 */
const RATE = 10_000_000n * 10n ** 18n;
const FEE_BPS = 250; // 2.5% fee untuk platform

describe("Mawar Finance (simple test)", () => {
  // Object untuk koneksi viem & hardhat runtime
  let viem: any;
  let publicClient: any;

  // Wallet testing dari hardhat
  let deployer: any;
  let user: any;

  // ABI & Bytecode contract
  let mfiAbi: Abi; let mfiByte: `0x${string}`;
  let nftAbi: Abi; let nftByte: `0x${string}`;
  let vaultAbi: Abi; let vaultByte: `0x${string}`;
  let exAbi: Abi; let exByte: `0x${string}`;

  // Alamat contract setelah deploy
  let mfi!: `0x${string}`;
  let nft!: `0x${string}`;
  let vault!: `0x${string}`;
  let exchange!: `0x${string}`;

  // Setup test environment sebelum running test
  before(async () => {
    const conn = await network.connect();  
    viem = conn.viem;

    const wallets = await viem.getWalletClients();
    [deployer, user] = wallets; // wallet 0 = owner, wallet 1 = user

    publicClient = await viem.getPublicClient();

    // Load compiled contract artifacts
    const MFI = await artifacts.readArtifact("MFI");
    mfiAbi = MFI.abi as Abi; mfiByte = MFI.bytecode as `0x${string}`;

    const NFT = await artifacts.readArtifact("SavingsNFT");
    nftAbi = NFT.abi as Abi; nftByte = NFT.bytecode as `0x${string}`;

    const V = await artifacts.readArtifact("SavingsVault");
    vaultAbi = V.abi as Abi; vaultByte = V.bytecode as `0x${string}`;

    const EX = await artifacts.readArtifact("Exchange");
    exAbi = EX.abi as Abi; exByte = EX.bytecode as `0x${string}`;
  });

  it("Deploy & Flow", async () => {
    // 1️⃣ Deploy token MFI (supply = 1,000,000 MFI)
    const initialSupply = parseUnits("1000000", 18);
    mfi = (await publicClient.waitForTransactionReceipt({
      hash: await deployer.deployContract({
        abi: mfiAbi, bytecode: mfiByte, args: [initialSupply],
      }),
    })).contractAddress!;

    // 2️⃣ Deploy NFT contract (buket bunga)
    nft = (await publicClient.waitForTransactionReceipt({
      hash: await deployer.deployContract({
        abi: nftAbi, bytecode: nftByte, args: [],
      }),
    })).contractAddress!;

    // 3️⃣ Deploy Vault (tempat deposit + NFT update)
    // param: MFI address, NFT address, treasury address, fee
    vault = (await publicClient.waitForTransactionReceipt({
      hash: await deployer.deployContract({
        abi: vaultAbi, bytecode: vaultByte,
        args: [mfi, nft, deployer.account.address, FEE_BPS],
      }),
    })).contractAddress!;

    // 4️⃣ Hubungkan NFT ke Vault (NFT cuma boleh minter vault)
    await publicClient.waitForTransactionReceipt({
      hash: await deployer.writeContract({
        address: nft, abi: nftAbi, functionName: "setVaultOnce",
        args: [vault],
      }),
    });

    // 5️⃣ Deploy Exchange (tempat user beli MFI pake ETH)
    exchange = (await publicClient.waitForTransactionReceipt({
      hash: await deployer.deployContract({
        abi: exAbi, bytecode: exByte, args: [mfi, RATE],
      }),
    })).contractAddress!;

    // 6️⃣ Seed liquidity di Exchange
    // Supaya user bisa beli token, exchange harus punya stok token dulu
    await publicClient.waitForTransactionReceipt({
      hash: await deployer.writeContract({
        address: mfi, abi: mfiAbi, functionName: "transfer",
        args: [exchange, parseUnits("200000", 18)], // deposit 200,000 MFI
      }),
    });

    // 7️⃣ User beli MFI pakai 0.01 ETH (~100,000 MFI)
    await publicClient.waitForTransactionReceipt({
      hash: await user.writeContract({
        address: exchange, abi: exAbi, functionName: "buyMFI",
        args: [user.account.address], value: parseEther("0.01"),
      }),
    });

    // 8️⃣ User approve Vault untuk spending 30 MFI
    await publicClient.waitForTransactionReceipt({
      hash: await user.writeContract({
        address: mfi, abi: mfiAbi, functionName: "approve",
        args: [vault, parseUnits("30", 18)],
      }),
    });

    // 9️⃣ Deposit 30 MFI → Mint 1 NFT Buket Mawar 🌹
    await publicClient.waitForTransactionReceipt({
      hash: await user.writeContract({
        address: vault, abi: vaultAbi, functionName: "deposit",
        args: [parseUnits("30", 18)],
      }),
    });

    // 🔟 Preview redeem NFT nanti
    const [principal, fee, payout] = await publicClient.readContract({
      address: vault, abi: vaultAbi, functionName: "previewRedeem",
      args: [1n],
    });

    // Validate hasil preview
    expect(principal).to.equal(parseUnits("30", 18)); // principal = 30 MFI
    expect(fee).to.equal((principal * BigInt(FEE_BPS)) / 10000n); // fee 2.5%
    expect(payout).to.equal(principal - fee); // payout = sisa setelah fee

    // 🧹 Terakhir, user redeem NFT → dapet MFI balik
    await publicClient.waitForTransactionReceipt({
      hash: await user.writeContract({
        address: vault, abi: vaultAbi, functionName: "redeem",
        args: [1n],
      }),
    });

    console.log("✅ BUY → DEPOSIT → REDEEM SUCCESS");
  });
});

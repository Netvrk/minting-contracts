import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { keccak256 } from "ethers/lib/utils";
import { ethers, upgrades } from "hardhat";
import { MerkleTree } from "merkletreejs";

describe("NFT World Staking & Rental", function () {
  let musicNft: Contract;
  let owner: Signer;
  let user: Signer;
  let user2: Signer;

  let ownerAddress: string;
  let userAddress: string;
  let user2Address: string;

  let whiteListAddresses: string[];
  let tree: MerkleTree;

  // Get signer
  before(async function () {
    [owner, user, user2] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    userAddress = await user.getAddress();
    user2Address = await user2.getAddress();

    whiteListAddresses = [userAddress, ownerAddress];

    tree = new MerkleTree(
      whiteListAddresses.map((x) => keccak256(x)),
      keccak256,
      { sortPairs: true }
    );
  });

  it("Deploy Music NFT contract", async function () {
    const MusicNFT = await ethers.getContractFactory("MusicNFT");
    musicNft = await upgrades.deployProxy(
      MusicNFT,
      ["DROP", "DROP", "https://api.example.com/", ownerAddress],
      {
        kind: "uups",
      }
    );
    await musicNft.deployed();
    expect(await musicNft.owner()).to.equal(ownerAddress);
  });

  it("Set merkel root and start presale", async function () {
    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).mintAlbum(hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MERKLE_ROOT_NOT_SET");

    const root = "0x" + tree.getRoot().toString("hex");
    await musicNft.setMerkleRoot(root);

    expect(await musicNft.presaleActive()).to.equal(false);
    await musicNft.startPresale("36", "12", "24", "10000000000000000000");
    expect(await musicNft.presaleActive()).to.equal(true);
  });

  it("Whitelisted user can mint album", async function () {
    const hexProof = tree.getHexProof(keccak256(userAddress));

    await musicNft.connect(user).mintAlbum(hexProof, {
      value: ethers.utils.parseEther("10"),
    });

    await musicNft.connect(user).mintAlbum(hexProof, {
      value: ethers.utils.parseEther("10"),
    });

    for (let x = 1; x < 25; x++) {
      expect(await musicNft.ownerOf(x)).to.equal(userAddress);
    }

    expect((await musicNft.balanceOf(userAddress)).toString()).to.equal("24");
    expect((await musicNft.albumsMinted()).toString()).to.equal("2");
    expect((await musicNft.totalSupply()).toString()).to.equal("24");

    expect((await musicNft.totalRevenue()).toString()).to.equal(
      "20000000000000000000"
    );
  });

  it("Non whitelisted user cannot mint album", async function () {
    const hexProof = tree.getHexProof(keccak256(user2Address));

    await expect(
      musicNft.connect(user2).mintAlbum(hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("NOT_WHITELISTED");
  });

  it("Whitelisted user cannot mint with wrong price", async function () {
    const hexProof = tree.getHexProof(keccak256(ownerAddress));
    await expect(
      musicNft.mintAlbum(hexProof, {
        value: ethers.utils.parseEther("9"),
      })
    ).to.be.revertedWith("INCORRECT_PRICE");
  });

  it("Check mint per wallet and presale limit", async function () {
    const hexProof = tree.getHexProof(keccak256(userAddress));

    await expect(
      musicNft.connect(user).mintAlbum(hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MAX_PER_WALLET_EXCEEDED");

    const hexProof2 = tree.getHexProof(keccak256(ownerAddress));

    await musicNft.mintAlbum(hexProof2, {
      value: ethers.utils.parseEther("10"),
    });

    await expect(
      musicNft.mintAlbum(hexProof2, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MAX_PRESALE_EXCEEDED");
  });

  it("Treasury address gets the withdraw amount", async function () {
    const balance = await owner.getBalance();
    await musicNft.withdraw();
    const balance2 = await owner.getBalance();
    expect(balance2.toString()).to.not.equal(balance.toString());
    await expect(musicNft.withdraw()).to.be.revertedWith("ZERO_BALANCE");
  });
});

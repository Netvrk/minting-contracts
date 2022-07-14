import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { keccak256 } from "ethers/lib/utils";
import { ethers, network, upgrades } from "hardhat";
import { MerkleTree } from "merkletreejs";

describe("Music NFT minting", function () {
  let musicNft: Contract;
  let owner: Signer;
  let user: Signer;
  let user2: Signer;

  let ownerAddress: string;
  let userAddress: string;
  let user2Address: string;

  let whiteListAddresses: string[];
  let tree: MerkleTree;
  let now: number;

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

    now = parseInt((new Date().getTime() / 1000).toString());
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

  it("Set merkel root", async function () {
    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MERKLE_ROOT_NOT_SET");

    const root = "0x" + tree.getRoot().toString("hex");
    await musicNft.setMerkleRoot(root);
  });

  it("Start presale for one day", async function () {
    expect(await musicNft.presaleActive()).to.equal(false);
    const startDate = now + 120;
    const endDate = now + 86400;
    await expect(
      musicNft.startPresale(
        "3",
        "2",
        "10000000000000000000",
        now + 120,
        now + 60
      )
    ).to.be.revertedWith("PRESALE_START_AFTER_END");

    await expect(
      musicNft.startPresale(
        "3",
        "2",
        "10000000000000000000",
        now - 1200,
        now + 8600
      )
    ).to.be.revertedWith("PRESALE_START_IN_PAST");

    await musicNft.startPresale(
      "3",
      "2",
      "10000000000000000000",
      startDate,
      endDate
    );
    expect(await musicNft.presaleActive()).to.equal(false);
    expect((await musicNft.maxAlbumOnSale()).toString()).to.equal("3");
    expect((await musicNft.maxAlbumPerWallet()).toString()).to.equal("2");
    expect((await musicNft.price()).toString()).to.equal(
      "10000000000000000000"
    );
    expect(await musicNft.presaleStart()).to.equal(startDate);
    expect(await musicNft.presaleEnd()).to.equal(endDate);
  });

  it("User can't mint before presale", async function () {
    expect(await musicNft.presaleActive()).to.equal(false);
    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("PRESALE_NOT_STARTED");
  });

  it("Whitelisted user can mint album", async function () {
    const mintableTime = now + 240;
    await network.provider.send("evm_setNextBlockTimestamp", [mintableTime]);
    await network.provider.send("evm_mine");

    expect(await musicNft.presaleActive()).to.equal(true);

    const hexProof = tree.getHexProof(keccak256(userAddress));

    await musicNft.connect(user).presaleMint(hexProof, {
      value: ethers.utils.parseEther("10"),
    });

    await musicNft.connect(user).presaleMint(hexProof, {
      value: ethers.utils.parseEther("10"),
    });

    for (let x = 1; x < 25; x++) {
      expect(await musicNft.ownerOf(x)).to.equal(userAddress);
    }
    expect((await musicNft.balanceOf(userAddress)).toString()).to.equal("24");
    expect((await musicNft.totalAlbumMinted()).toString()).to.equal("2");
    expect((await musicNft.totalSupply()).toString()).to.equal("24");
    expect((await musicNft.totalRevenue()).toString()).to.equal(
      "20000000000000000000"
    );
  });

  it("Non whitelisted user cannot mint album", async function () {
    const hexProof = tree.getHexProof(keccak256(user2Address));

    await expect(
      musicNft.connect(user2).presaleMint(hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("NOT_WHITELISTED");
  });

  it("User cant mint in public sale while presale is active", async function () {
    await expect(
      musicNft.connect(user2).mint({
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("SALE_NOT_ACTIVE");
  });

  it("Whitelisted user cannot mint with wrong price", async function () {
    const hexProof = tree.getHexProof(keccak256(ownerAddress));
    await expect(
      musicNft.presaleMint(hexProof, {
        value: ethers.utils.parseEther("9"),
      })
    ).to.be.revertedWith("INCORRECT_PRICE");
  });

  it("Check mint per wallet and presale limit", async function () {
    const hexProof = tree.getHexProof(keccak256(userAddress));

    await expect(
      musicNft.connect(user).presaleMint(hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MAX_PER_WALLET_EXCEEDED");

    const hexProof2 = tree.getHexProof(keccak256(ownerAddress));

    await musicNft.presaleMint(hexProof2, {
      value: ethers.utils.parseEther("10"),
    });

    await expect(
      musicNft.presaleMint(hexProof2, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MAX_PRESALE_EXCEEDED");
  });

  it("User can't mint after presale", async function () {
    const mintableTime = now + 86401;
    await network.provider.send("evm_setNextBlockTimestamp", [mintableTime]);
    await network.provider.send("evm_mine");

    expect(await musicNft.presaleActive()).to.equal(false);

    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("PRESALE_ENDED");
  });

  it("Start sale after one day", async function () {
    await musicNft.startSale("3", "2", "10000000000000000000");

    expect(await musicNft.presaleActive()).to.equal(false);
    expect(await musicNft.saleActive()).to.equal(true);
    expect((await musicNft.maxAlbumOnSale()).toString()).to.equal("6");
    expect((await musicNft.maxAlbumPerWallet()).toString()).to.equal("2");
    expect((await musicNft.price()).toString()).to.equal(
      "10000000000000000000"
    );
  });

  it("Any user can mint album in sale", async function () {
    await musicNft.connect(user2).mint({
      value: ethers.utils.parseEther("10"),
    });

    const supply = parseInt((await musicNft.totalSupply()).toString());
    for (let x = supply - 11; x <= supply; x++) {
      expect(await musicNft.ownerOf(x)).to.equal(user2Address);
    }
    expect((await musicNft.balanceOf(user2Address)).toString()).to.equal("12");
    expect((await musicNft.totalSupply()).toString()).to.equal("48");
  });

  it("User can't mint after the sale is stopped", async function () {
    await musicNft.stopSale();
    await expect(
      musicNft.connect(user2).mint({
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("SALE_NOT_ACTIVE");
  });

  it("Treasury account gets the withdraw amount", async function () {
    const balance = await owner.getBalance();
    await musicNft.withdraw();
    const balance2 = await owner.getBalance();
    expect(balance2.toString()).to.not.equal(balance.toString());
    await expect(musicNft.withdraw()).to.be.revertedWith("ZERO_BALANCE");
  });
});

import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { Signer } from "ethers";
import { keccak256 } from "ethers/lib/utils";
import { ethers, upgrades } from "hardhat";
import { MerkleTree } from "merkletreejs";
import { MusicNFT, NFT } from "../typechain";

describe("Music NFT minting contracts test", function () {
  let musicNft: MusicNFT;
  let nft: NFT;
  let owner: Signer;
  let user: Signer;
  let user2: Signer;

  let ownerAddress: string;
  let userAddress: string;
  let user2Address: string;

  let whiteListAddresses: string[];
  let tree: MerkleTree;
  let now: number;
  let tracksPerAlbum: number;
  let maxAlbumsPerTx: number;

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

    now = await time.latest();
    tracksPerAlbum = 12;
    maxAlbumsPerTx = 3;
  });

  it("Should deploy avatar contract", async function () {
    const NFT = await ethers.getContractFactory("NFT");
    nft = (await upgrades.deployProxy(
      NFT,
      ["AVTR", "AVTR", "https://api.example.com/"],
      {
        kind: "uups",
      }
    )) as NFT;

    await nft.deployed();
  });

  it("Should deploy music contract", async function () {
    const MusicNFT = await ethers.getContractFactory("MusicNFT");
    musicNft = (await upgrades.deployProxy(
      MusicNFT,
      [
        "DROP",
        "DROP",
        "https://api.example.com/",
        ownerAddress,
        nft.address,
        ownerAddress,
      ],
      {
        kind: "uups",
      }
    )) as MusicNFT;
    await musicNft.deployed();
  });

  it("Should set minting contract as minter in avatar contract", async function () {
    const MINTER_ROLE = await nft.MINTER_ROLE();
    await nft.grantRole(MINTER_ROLE, musicNft.address);
    expect(await nft.hasRole(MINTER_ROLE, musicNft.address)).to.equal(true);
  });

  it("User shouldn't premint before merkel root is set", async function () {
    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MERKLE_ROOT_NOT_SET");
  });

  it("Should set merkel root for owner and user", async function () {
    const root = "0x" + tree.getRoot().toString("hex");
    await musicNft.setMerkleRoot(root);
  });

  it("User shouldn't premint before presale is started", async function () {
    expect(await musicNft.presaleActive()).to.equal(false);
    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("PRESALE_NOT_ACTIVE");
  });

  it("Shouldn't start presale before end", async function () {
    await expect(
      musicNft.startPresale(
        "5",
        "3",
        "10000000000000000000",
        now + 120,
        now + 60
      )
    ).to.be.revertedWith("PRESALE_START_AFTER_END");
  });

  it("Shouldn't start presale in past", async function () {
    await expect(
      musicNft.startPresale(
        "5",
        "3",
        "10000000000000000000",
        now - 1200,
        now + 8600
      )
    ).to.be.revertedWith("PRESALE_START_IN_PAST");
  });

  it("Shouldn't start presale with zero max per wallet and zero max amount", async function () {
    const startDate = now + 120;
    const endDate = now + 86400;
    await expect(
      musicNft.startPresale(
        "0",
        "3",
        "10000000000000000000",
        startDate,
        endDate
      )
    ).to.be.revertedWith("SMALLER_MAX_ALBUMS");

    await expect(
      musicNft.startPresale(
        "10",
        "0",
        "10000000000000000000",
        startDate,
        endDate
      )
    ).to.be.revertedWith("SMALLER_MAX_ALBUMS_PER_WALLET");
  });

  it("Should start presale with appropriate duration (1 day)", async function () {
    const startDate = now + 120;
    const endDate = now + 86400;
    await musicNft.startPresale(
      "5",
      "3",
      "10000000000000000000",
      startDate,
      endDate
    );
    expect(await musicNft.presaleActive()).to.equal(false);
    expect((await musicNft.maxAlbumsOnSale()).toString()).to.equal("5");
    expect((await musicNft.maxAlbumsPerWallet()).toString()).to.equal("3");
    expect((await musicNft.price()).toString()).to.equal(
      "10000000000000000000"
    );
    expect(await musicNft.presaleStart()).to.equal(startDate);
    expect(await musicNft.presaleEnd()).to.equal(endDate);
  });

  it("Whitelisted user shouldn't premint before presale start time", async function () {
    expect(await musicNft.presaleActive()).to.equal(false);
    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("PRESALE_NOT_STARTED");
  });

  it("Whitelisted users should premint in presale", async function () {
    const mintableTime = now + 240;
    await time.increaseTo(mintableTime);

    expect(await musicNft.presaleActive()).to.equal(true);

    const hexProof = tree.getHexProof(keccak256(userAddress));

    await musicNft.connect(user).presaleMint(1, hexProof, {
      value: ethers.utils.parseEther("10"),
    });

    await musicNft.connect(user).presaleMint(1, hexProof, {
      value: ethers.utils.parseEther("10"),
    });

    for (let x = 1; x <= tracksPerAlbum * 2; x++) {
      expect(await musicNft.ownerOf(x)).to.equal(userAddress);
    }
    expect((await musicNft.balanceOf(userAddress)).toString()).to.equal(
      (tracksPerAlbum * 2).toString()
    );
    expect((await musicNft.albumsMinted(userAddress)).toString()).to.equal("2");
    expect((await musicNft.totalAlbumsMinted()).toString()).to.equal("2");
    expect((await musicNft.totalSupply()).toString()).to.equal(
      (tracksPerAlbum * 2).toString()
    );
    expect((await musicNft.totalRevenue()).toString()).to.equal(
      "20000000000000000000"
    );
    expect((await nft.totalSupply()).toString()).to.equal("2");
  });

  it("Non whitelisted users shouldn't premint in presale", async function () {
    const hexProof = tree.getHexProof(keccak256(user2Address));

    await expect(
      musicNft.connect(user2).presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("NOT_WHITELISTED");
  });

  it("User shouldn't mint in sale while presale is active", async function () {
    await expect(
      musicNft.connect(user2).mint(1, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("SALE_NOT_ACTIVE");
  });

  it("Whitelisted user shouldn't premint with wrong price", async function () {
    const hexProof = tree.getHexProof(keccak256(ownerAddress));
    await expect(
      musicNft.presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("9"),
      })
    ).to.be.revertedWith("LOW_PRICE");
  });

  it("Whitelisted user shouldn't mint after presale end time", async function () {
    const mintableTime = now + 86401;
    await time.increaseTo(mintableTime);

    expect(await musicNft.presaleActive()).to.equal(false);

    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("PRESALE_ENDED");
  });

  it("Should premint after extending presale end time", async function () {
    expect(await musicNft.presaleActive()).to.equal(false);

    const prevPresaleEnd = parseInt((await musicNft.presaleEnd()).toString());

    await musicNft.extendPresale(prevPresaleEnd + 86400);

    expect(await musicNft.presaleActive()).to.equal(true);

    const hexProof = tree.getHexProof(keccak256(userAddress));
    await musicNft.connect(user).presaleMint(1, hexProof, {
      value: ethers.utils.parseEther("10"),
    });

    expect((await musicNft.albumsMinted(userAddress)).toString()).to.equal("3");
  });

  it("Shouldn't extend presale in past", async function () {
    const currentTime = await time.latest();
    await expect(musicNft.extendPresale(currentTime - 120)).to.be.revertedWith(
      "PRESALE_ENDS_IN_PAST"
    );
  });

  it("Shouldn't extend presale before last end", async function () {
    const prevPresaleEnd = parseInt((await musicNft.presaleEnd()).toString());
    await expect(
      musicNft.extendPresale(prevPresaleEnd - 120)
    ).to.be.revertedWith("PRESALE_ENDS_BEFORE_LAST_END");
  });

  it("Whitelisted user shouldn't premint if max per wallet is exceeded", async function () {
    const hexProof = tree.getHexProof(keccak256(userAddress));

    await expect(
      musicNft.connect(user).presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MAX_PER_WALLET_EXCEEDED");
  });

  it("Whitelisted users shouldn't premint if max amount is exceeded", async function () {
    const hexProof2 = tree.getHexProof(keccak256(ownerAddress));

    await musicNft.presaleMint(1, hexProof2, {
      value: ethers.utils.parseEther("10"),
    });

    await musicNft.presaleMint(1, hexProof2, {
      value: ethers.utils.parseEther("10"),
    });

    await expect(
      musicNft.presaleMint(1, hexProof2, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MAX_AMOUNT_EXCEEDED");
  });

  it("Shouldn't start public sale with max amount zero or less than in presale", async function () {
    await expect(
      musicNft.startSale("0", "6", "10000000000000000000")
    ).to.be.revertedWith("SMALLER_MAX_ALBUMS");

    await expect(
      musicNft.startSale("5", "6", "10000000000000000000")
    ).to.be.revertedWith("SMALLER_MAX_ALBUMS");

    await expect(
      musicNft.startSale("4", "6", "10000000000000000000")
    ).to.be.revertedWith("SMALLER_MAX_ALBUMS");
  });

  it("Shouldn't start public sale with zero max per wallet", async function () {
    await expect(
      musicNft.startSale("15", "0", "10000000000000000000")
    ).to.be.revertedWith("SMALLER_MAX_ALBUMS_PER_WALLET");
  });

  it("Should stop presale and start public sale", async function () {
    await musicNft.startSale("15", "6", "10000000000000000000");

    expect(await musicNft.presaleActive()).to.equal(false);
    expect(await musicNft.saleActive()).to.equal(true);
    expect((await musicNft.maxAlbumsOnSale()).toString()).to.equal("15");
    expect((await musicNft.maxAlbumsPerWallet()).toString()).to.equal("6");
    expect((await musicNft.price()).toString()).to.equal(
      "10000000000000000000"
    );
  });

  it("Whitelisted users shouldn't premint once sale becomes active", async function () {
    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("PRESALE_NOT_ACTIVE");
  });

  it("Any user should mint in sale", async function () {
    await expect(
      musicNft.connect(user2).mint(maxAlbumsPerTx + 1, {
        value: ethers.utils.parseEther("60"),
      })
    ).to.be.revertedWith("TOO_MANY_ALBUMS");

    await musicNft.connect(user2).mint(2, {
      value: ethers.utils.parseEther("20"),
    });

    expect((await musicNft.balanceOf(user2Address)).toString()).to.equal(
      (2 * tracksPerAlbum).toString()
    );
    expect((await musicNft.albumsMinted(user2Address)).toString()).to.equal(
      "2"
    );
    expect((await nft.balanceOf(user2Address)).toString()).to.equal("2");
  });

  it("Uer shouldn't mint if max per wallet is exceeded", async function () {
    await musicNft.connect(user2).mint(2, {
      value: ethers.utils.parseEther("20"),
    });

    await musicNft.connect(user2).mint(2, {
      value: ethers.utils.parseEther("20"),
    });

    await expect(
      musicNft.connect(user2).mint(1, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MAX_PER_WALLET_EXCEEDED");
  });

  it("Users shouldn't mint if max amount is exceeded", async function () {
    await musicNft.connect(user).mint(2, {
      value: ethers.utils.parseEther("20"),
    });
    await musicNft.mint(2, {
      value: ethers.utils.parseEther("20"),
    });

    await expect(
      musicNft.connect(user).mint(1, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("MAX_AMOUNT_EXCEEDED");
  });

  it("User shouldn't mint after the sale is stopped", async function () {
    await musicNft.stopSale();
    const hexProof = tree.getHexProof(keccak256(userAddress));
    await expect(
      musicNft.connect(user).presaleMint(1, hexProof, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("PRESALE_NOT_ACTIVE");

    await expect(
      musicNft.connect(user2).mint(1, {
        value: ethers.utils.parseEther("10"),
      })
    ).to.be.revertedWith("SALE_NOT_ACTIVE");
  });

  it("Treasury account should get the withdraw amount", async function () {
    const balance = await owner.getBalance();
    await musicNft.withdraw();
    const balance2 = await owner.getBalance();
    expect(balance2.toString()).to.not.equal(balance.toString());
    await expect(musicNft.withdraw()).to.be.revertedWith("ZERO_BALANCE");
  });
});

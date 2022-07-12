/*
=====================================================
███╗   ██╗███████╗████████╗██╗   ██╗██████╗ ██╗  ██╗
████╗  ██║██╔════╝╚══██╔══╝██║   ██║██╔══██╗██║ ██╔╝
██╔██╗ ██║█████╗     ██║   ██║   ██║██████╔╝█████╔╝ 
██║╚██╗██║██╔══╝     ██║   ╚██╗ ██╔╝██╔══██╗██╔═██╗ 
██║ ╚████║███████╗   ██║    ╚████╔╝ ██║  ██║██║  ██╗
╚═╝  ╚═══╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═╝
=====================================================
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MusicNFT is
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ERC721EnumerableUpgradeable
{
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using MerkleProofUpgradeable for bytes32[];

    address internal _treasury;
    uint256 internal _totalRevenue;
    bytes32 private _merkleRoot;
    string private _tokenBaseURI;
    bool private _presaleActive;

    // Sales Parameters
    uint256 private _maxAmount;
    uint256 private _musicsInAlbum;
    uint256 private _maxPerWallet;
    uint256 private _startIndex;
    uint256 private _price;

    mapping(address => uint256) private _mintCount;

    modifier onlyMintable() {
        require(
            _maxAmount > 0
                ? totalSupply().add(_musicsInAlbum) <= _maxAmount
                : true,
            "MAX_PRESALE_EXCEEDED"
        );

        require(
            _mintCount[_msgSender()].add(_musicsInAlbum) <= _maxPerWallet,
            "MAX_PER_WALLET_EXCEEDED"
        );

        _;
    }

    event MerkleRootSet(bytes32 indexed merkleRoot);

    /**
    ////////////////////////////////////////////////////
    // Admin Functions 
    ///////////////////////////////////////////////////
    */

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address treasury_
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __ERC721Enumerable_init();
        __UUPSUpgradeable_init();
        __Context_init_unchained();
        __Ownable_init_unchained();

        _tokenBaseURI = baseURI_;
        _treasury = treasury_;
        _presaleActive = false;
        _startIndex = 1;
    }

    // Set merkle root
    function setMerkleRoot(bytes32 newRoot) public onlyOwner {
        _merkleRoot = newRoot;
        emit MerkleRootSet(newRoot);
    }

    // Set treasury address
    function setTreasury(address newTreasury) public onlyOwner {
        _treasury = newTreasury;
    }

    // Set NFT base URI
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _tokenBaseURI = newBaseURI;
    }

    // Start presale
    function startPresale(
        uint256 newMaxAmount,
        uint256 nexMaxInAlbum,
        uint256 newMaxPerWallet,
        uint256 newPrice
    ) public onlyOwner {
        _maxAmount = newMaxAmount;
        _musicsInAlbum = nexMaxInAlbum;
        _maxPerWallet = newMaxPerWallet;
        _price = newPrice;
        _presaleActive = true;
    }

    // Stop presale
    function stopPresale() public onlyOwner {
        _presaleActive = false;
    }

    // withdraw all incomes
    function withdraw() public {
        require(address(this).balance > 0, "ZERO_BALANCE");
        uint256 balance = address(this).balance;
        AddressUpgradeable.sendValue(payable(_treasury), balance);
    }

    /**
    ////////////////////////////////////////////////////
    // Public Functions 
    ///////////////////////////////////////////////////
    */

    // Mint album
    function mintAlbum(bytes32[] calldata proof) public payable onlyMintable {
        require(_merkleRoot != "", "MERKLE_ROOT_NOT_SET");
        require(_presaleActive, "PRESALE_NOT_ACTIVE");
        require(
            MerkleProofUpgradeable.verify(
                proof,
                _merkleRoot,
                keccak256(abi.encodePacked(_msgSender()))
            ),
            "NOT_WHITELISTED"
        );
        _presaleMint(_msgSender());
    }

    /**
    ////////////////////////////////////////////////////
    // View only functions
    ///////////////////////////////////////////////////
    */

    function maxAmount() external view returns (uint256) {
        return _maxAmount;
    }

    function musicsInAlbum() external view returns (uint256) {
        return _musicsInAlbum;
    }

    function maxPerWallet() external view returns (uint256) {
        return _maxPerWallet;
    }

    function price() external view returns (uint256) {
        return _price;
    }

    function presaleActive() external view returns (bool) {
        return _presaleActive;
    }

    function mintCount(address user) external view returns (uint256) {
        return _mintCount[user];
    }

    function albumsMinted() public view returns (uint256) {
        return _startIndex.div(_musicsInAlbum);
    }

    function treasury() external view returns (address) {
        return _treasury;
    }

    function totalRevenue() external view returns (uint256) {
        return _totalRevenue;
    }

    /**
    ////////////////////////////////////////////////////
    // Internal Functions 
    ///////////////////////////////////////////////////
    */

    function _presaleMint(address sender) internal {
        require(_price <= msg.value, "INCORRECT_PRICE");
        _totalRevenue = _totalRevenue.add(msg.value);
        _mintCount[sender] = _mintCount[sender].add(_musicsInAlbum);
        _mint(sender);
    }

    function _mint(address sender) internal {
        for (
            uint256 idx = _startIndex;
            idx < _startIndex + _musicsInAlbum;
            idx++
        ) {
            _safeMint(sender, idx);
        }
        _startIndex = _startIndex.add(_musicsInAlbum);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _tokenBaseURI;
    }

    /**
    ////////////////////////////////////////////////////
    // Override Functions 
    ///////////////////////////////////////////////////
    */
    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function transferOwnership(address newOwner)
        public
        override(OwnableUpgradeable)
    {
        return OwnableUpgradeable.transferOwnership(newOwner);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // UUPS proxy function
    function _authorizeUpgrade(address) internal override onlyOwner {}
}

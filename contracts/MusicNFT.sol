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
    bool private _saleActive;

    // Sales Parameters
    uint256 private _maxAmount;
    uint256 private _musicsInAlbum;
    uint256 private _maxPerWallet;
    uint256 private _startIndex;
    uint256 private _price;
    uint256 private _presaleStart;
    uint256 private _presaleEnd;

    mapping(address => uint256) private _mintCount;

    modifier onlyPresaleMintable() {
        require(_merkleRoot != "", "MERKLE_ROOT_NOT_SET");
        require(_presaleActive, "PRESALE_NOT_ACTIVE");
        require(_presaleStart < block.timestamp, "PRESALE_NOT_STARTED");
        require(block.timestamp < _presaleEnd, "PRESALE_ENDED");
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

    modifier onlySaleMintable() {
        require(_saleActive, "SALE_NOT_ACTIVE");
        require(
            _maxAmount > 0
                ? totalSupply().add(_musicsInAlbum) <= _maxAmount
                : true,
            "MAX_SALE_EXCEEDED"
        );
        require(
            _mintCount[_msgSender()].add(_musicsInAlbum) <= _maxPerWallet,
            "MAX_PER_WALLET_EXCEEDED"
        );
        _;
    }

    event Minted(uint256 indexed tokenId, address indexed user);

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
        _saleActive = false;
        _startIndex = 1;
        _musicsInAlbum = 12;
    }

    // Set merkle root
    function setMerkleRoot(bytes32 newRoot) public onlyOwner {
        _merkleRoot = newRoot;
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
        uint256 maxAlbums,
        uint256 maxAlbumsPerWallet,
        uint256 newPrice,
        uint256 presaleStartDate,
        uint256 presaleEndDate
    ) public onlyOwner {
        require(presaleStartDate < presaleEndDate, "PRESALE_START_AFTER_END");
        require(presaleStartDate > block.timestamp, "PRESALE_START_IN_PAST");

        _maxAmount = maxAlbums.mul(_musicsInAlbum);
        _maxPerWallet = maxAlbumsPerWallet.mul(_musicsInAlbum);
        _price = newPrice;
        _presaleStart = presaleStartDate;
        _presaleEnd = presaleEndDate;
        _presaleActive = true;
        _saleActive = false;
    }

    // Start sale
    function startSale(
        uint256 maxAlbums,
        uint256 maxAlbumsPerWallet,
        uint256 newPrice
    ) public onlyOwner {
        _maxAmount = _maxAmount.add(maxAlbums.mul(_musicsInAlbum));
        _maxPerWallet = maxAlbumsPerWallet.mul(_musicsInAlbum);
        _price = newPrice;
        _presaleActive = false;
        _saleActive = true;
    }

    function stopSale() public onlyOwner {
        _saleActive = false;
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

    // Mint album in presale
    function presaleMint(bytes32[] calldata proof)
        public
        payable
        onlyPresaleMintable
    {
        require(
            MerkleProofUpgradeable.verify(
                proof,
                _merkleRoot,
                keccak256(abi.encodePacked(_msgSender()))
            ),
            "NOT_WHITELISTED"
        );
        _mintAlbum(_msgSender());
    }

    // mint album in sale
    function mint() public payable onlySaleMintable {
        _mintAlbum(_msgSender());
    }

    /**
    ////////////////////////////////////////////////////
    // View only functions
    ///////////////////////////////////////////////////
    */

    function musicsInAlbum() external view returns (uint256) {
        return _musicsInAlbum;
    }

    function maxAlbumOnSale() external view returns (uint256) {
        return _maxAmount.div(_musicsInAlbum);
    }

    function maxAlbumPerWallet() external view returns (uint256) {
        return _maxPerWallet.div(_musicsInAlbum);
    }

    function price() external view returns (uint256) {
        return _price;
    }

    function presaleActive() external view returns (bool) {
        return
            _presaleActive &&
            _presaleStart < block.timestamp &&
            _presaleEnd > block.timestamp;
    }

    function saleActive() external view returns (bool) {
        return _saleActive;
    }

    function presaleStart() external view returns (uint256) {
        return _presaleStart;
    }

    function presaleEnd() external view returns (uint256) {
        return _presaleEnd;
    }

    function musicMinted(address user) external view returns (uint256) {
        return _mintCount[user];
    }

    function albumMinted(address user) external view returns (uint256) {
        return _mintCount[user].div(_musicsInAlbum);
    }

    function totalAlbumMinted() public view returns (uint256) {
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

    function _mintAlbum(address sender) internal {
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
            emit Minted(idx, sender);
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

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
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./interfaces/IMusicNFT.sol";
import "./interfaces/INFT.sol";

contract MusicNFT is
    IMusicNFT,
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
    uint256 private _maxTracks;
    uint256 private _tracksPerAlbum;
    uint256 private _maxAlbumsPerTx;
    uint256 private _maxPerWallet;
    uint256 private _startIndex;
    uint256 private _price;
    uint256 private _presaleStart;
    uint256 private _presaleEnd;

    mapping(address => uint256) private _mintedTracks;

    // Avatar NFT
    INFT private _avatarNFT;

    modifier onlyPresaleMintable(uint256 albums) {
        require(_merkleRoot != "", "MERKLE_ROOT_NOT_SET");
        require(_presaleActive, "PRESALE_NOT_ACTIVE");
        require(_presaleStart < block.timestamp, "PRESALE_NOT_STARTED");
        require(block.timestamp < _presaleEnd, "PRESALE_ENDED");
        require(
            _maxTracks > 0
                ? totalSupply().add(_tracksPerAlbum.mul(albums)) <= _maxTracks
                : true,
            "MAX_PRESALE_EXCEEDED"
        );
        require(
            _mintedTracks[_msgSender()].add(_tracksPerAlbum.mul(albums)) <=
                _maxPerWallet,
            "MAX_PER_WALLET_EXCEEDED"
        );
        _;
    }

    modifier onlySaleMintable(uint256 albums) {
        require(_saleActive, "SALE_NOT_ACTIVE");
        require(
            _maxTracks > 0
                ? totalSupply().add(_tracksPerAlbum.mul(albums)) <= _maxTracks
                : true,
            "MAX_SALE_EXCEEDED"
        );
        require(
            _mintedTracks[_msgSender()].add(_tracksPerAlbum.mul(albums)) <=
                _maxPerWallet,
            "MAX_PER_WALLET_EXCEEDED"
        );
        _;
    }

    /**
    ////////////////////////////////////////////////////
    // Admin Functions 
    ///////////////////////////////////////////////////
    */

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address treasury_,
        INFT avatarNFTAddress_
    ) public initializer {
        require(
            avatarNFTAddress_.supportsInterface(type(INFT).interfaceId),
            "INVALID_AVATAR_NFT_ADDRESS"
        );

        __ERC721_init(name_, symbol_);
        __ERC721Enumerable_init();
        __UUPSUpgradeable_init();
        __Context_init_unchained();
        __Ownable_init_unchained();

        _tokenBaseURI = baseURI_;
        _treasury = treasury_;
        _avatarNFT = avatarNFTAddress_;
        _presaleActive = false;
        _saleActive = false;
        _startIndex = 1;
        _tracksPerAlbum = 12;
        _maxAlbumsPerTx = 2;
    }

    // Set merkle root
    function setMerkleRoot(bytes32 merkleRoot_) external virtual onlyOwner {
        _merkleRoot = merkleRoot_;
    }

    // Set treasury address
    function setTreasury(address newTreaasury_) external virtual onlyOwner {
        _treasury = newTreaasury_;
    }

    // Set NFT base URI
    function setBaseURI(string memory newBaseURI_) external virtual onlyOwner {
        _tokenBaseURI = newBaseURI_;
    }

    // Start presale
    function startPresale(
        uint256 maxAlbums_,
        uint256 maxAlbumsPerWallet_,
        uint256 newPrice_,
        uint256 presaleStartTime_,
        uint256 presaleEndTime_
    ) external virtual onlyOwner {
        require(presaleStartTime_ < presaleEndTime_, "PRESALE_START_AFTER_END");
        require(presaleStartTime_ > block.timestamp, "PRESALE_START_IN_PAST");
        require(maxAlbums_ > 0, "MAX_ALBUMS_ZERO");
        require(maxAlbumsPerWallet_ > 0, "MAX_ALBUMS_PER_WALLET_ZERO");

        _maxTracks = maxAlbums_.mul(_tracksPerAlbum);
        _maxPerWallet = maxAlbumsPerWallet_.mul(_tracksPerAlbum);
        _price = newPrice_;
        _presaleStart = presaleStartTime_;
        _presaleEnd = presaleEndTime_;
        _presaleActive = true;
        _saleActive = false;
    }

    // extend presale period
    function extendPresale(uint256 presaleEndTime_) external virtual onlyOwner {
        require(presaleEndTime_ > block.timestamp, "PRESALE_ENDS_IN_PAST");
        require(presaleEndTime_ > _presaleEnd, "PRESALE_ENDS_BEFORE_LAST_END");
        _presaleEnd = presaleEndTime_;
    }

    // Start sale
    function startSale(
        uint256 maxAlbums_,
        uint256 maxAlbumsPerWallet_,
        uint256 newPrice_
    ) external virtual onlyOwner {
        require(maxAlbums_ > 0, "MAX_ALBUMS_ZERO");
        require(
            maxAlbums_.mul(_tracksPerAlbum) > _maxTracks,
            "SMALLER_MAX_ALBUMS"
        );
        require(maxAlbumsPerWallet_ > 0, "MAX_ALBUMS_PER_WALLET_ZERO");

        _maxTracks = maxAlbums_.mul(_tracksPerAlbum);
        _maxPerWallet = maxAlbumsPerWallet_.mul(_tracksPerAlbum);
        _price = newPrice_;
        _presaleActive = false;
        _saleActive = true;
    }

    function stopSale() external virtual onlyOwner {
        _saleActive = false;
    }

    // withdraw all incomes
    function withdraw() external virtual {
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
    function presaleMint(uint256 albums_, bytes32[] calldata proof_)
        external
        payable
        virtual
        onlyPresaleMintable(albums_)
    {
        require(
            MerkleProofUpgradeable.verify(
                proof_,
                _merkleRoot,
                keccak256(abi.encodePacked(_msgSender()))
            ),
            "NOT_WHITELISTED"
        );
        _mintAlbum(_msgSender(), albums_);
    }

    // mint album in sale
    function mint(uint256 albums_)
        external
        payable
        virtual
        onlySaleMintable(albums_)
    {
        _mintAlbum(_msgSender(), albums_);
    }

    /**
    ////////////////////////////////////////////////////
    // View only functions
    ///////////////////////////////////////////////////
    */

    function tracksPerAlbum() external view virtual returns (uint256) {
        return _tracksPerAlbum;
    }

    function maxTracksOnSale() external view virtual returns (uint256) {
        return _maxTracks;
    }

    function maxAlbumsOnSale() external view virtual returns (uint256) {
        return _maxTracks.div(_tracksPerAlbum);
    }

    function maxAlbumsPerWallet() external view virtual returns (uint256) {
        return _maxPerWallet.div(_tracksPerAlbum);
    }

    function maxAlbumsPerTx() external view virtual returns (uint256) {
        return _maxAlbumsPerTx;
    }

    function price() external view virtual returns (uint256) {
        return _price;
    }

    function presaleActive() external view virtual returns (bool) {
        return
            _presaleActive &&
            _presaleStart < block.timestamp &&
            _presaleEnd > block.timestamp;
    }

    function saleActive() external view virtual returns (bool) {
        return _saleActive;
    }

    function presaleStart() external view virtual returns (uint256) {
        return _presaleStart;
    }

    function presaleEnd() external view virtual returns (uint256) {
        return _presaleEnd;
    }

    function tracksMinted(address user)
        external
        view
        virtual
        returns (uint256)
    {
        return _mintedTracks[user];
    }

    function albumsMinted(address user)
        external
        view
        virtual
        returns (uint256)
    {
        return _mintedTracks[user].div(_tracksPerAlbum);
    }

    function totalAlbumsMinted() public view returns (uint256) {
        return _startIndex.div(_tracksPerAlbum);
    }

    function treasury() external view virtual returns (address) {
        return _treasury;
    }

    function totalRevenue() external view virtual returns (uint256) {
        return _totalRevenue;
    }

    /**
    ////////////////////////////////////////////////////
    // Internal Functions 
    ///////////////////////////////////////////////////
    */

    function _mintAlbum(address sender, uint256 albums) internal {
        require(albums <= _maxAlbumsPerTx, "TOO_MANY_ALBUMS");
        require(_price.mul(albums) <= msg.value, "LOW_PRICE");
        uint256 totalMints = albums.mul(_tracksPerAlbum);

        for (uint256 idx = _startIndex; idx < _startIndex + totalMints; idx++) {
            _safeMint(sender, idx);
            emit Minted(idx, sender);
        }

        _totalRevenue = _totalRevenue.add(msg.value);
        _mintedTracks[sender] = _mintedTracks[sender].add(totalMints);
        _startIndex = _startIndex.add(totalMints);

        // Mint avatar for user
        for (uint256 idx = 0; idx < albums; idx++) {
            _avatarNFT.mintItem(sender);
        }
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
        override(IERC165, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IMusicNFT).interfaceId ||
            super.supportsInterface(interfaceId);
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

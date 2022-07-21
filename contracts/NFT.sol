// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./interfaces/INFT.sol";

contract NFT is
    INFT,
    UUPSUpgradeable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string internal _baseTokenURI;

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) public initializer {
        __UUPSUpgradeable_init_unchained();
        __AccessControl_init_unchained();
        __Pausable_init_unchained();

        __ERC721_init_unchained(name, symbol);
        _baseTokenURI = baseTokenURI;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Mint item
    function mintItem(address user)
        external
        virtual
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        _mint(user, newItemId);
        _tokenIds.increment();
        return newItemId;
    }

    // Set base URI
    function setBaseURI(string memory baseTokenURI)
        external
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _baseTokenURI = baseTokenURI;
    }

    // Get base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(INFT).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // UUPS proxy function
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}

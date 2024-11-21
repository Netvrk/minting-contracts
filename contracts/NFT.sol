// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./interfaces/INFT.sol";

/**
 * @title NFT
 * @dev This contract implements an upgradeable ERC721 token with enumerable, pausable, and access control features.
 * It also supports ERC2981 for royalty management and UUPS proxy for upgradeability.
 * The contract allows minting of new tokens by users with the MINTER_ROLE and setting base URI, contract URI, and default royalty by users with the DEFAULT_ADMIN_ROLE.
 */
contract NFT is
    INFT,
    ERC2981,
    UUPSUpgradeable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string internal _baseTokenURI;
    string private _contractURI;

    /**
     * @dev Initializes the contract with the given name, symbol, and base token URI.
     * Grants the deployer the default admin role.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param baseTokenURI The base URI for the token metadata.
     */
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

        // Start indexing from 1
        _tokenIds.increment();
    }

    /**
     * @dev Mints a new token to the specified user.
     * Can only be called by users with the MINTER_ROLE.
     * @param user The address of the user to mint the token to.
     * @return The ID of the newly minted token.
     */
    function mintItem(
        address user
    ) external virtual onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 newItemId = _tokenIds.current();
        _mint(user, newItemId);
        _tokenIds.increment();
        return newItemId;
    }

    /**
     * @dev Sets the base URI for the token metadata.
     * Can only be called by users with the DEFAULT_ADMIN_ROLE.
     * @param baseTokenURI The new base URI.
     */
    function setBaseURI(
        string memory baseTokenURI
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev Sets the default royalty information.
     * Can only be called by users with the DEFAULT_ADMIN_ROLE.
     * @param receiver The address of the royalty receiver.
     * @param royalty The royalty percentage (in basis points).
     */
    function setDefaultRoyalty(
        address receiver,
        uint96 royalty
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDefaultRoyalty(receiver, royalty);
    }

    /**
     * @dev Sets the contract URI.
     * Can only be called by users with the DEFAULT_ADMIN_ROLE.
     * @param newContractURI The new contract URI.
     */
    function setContractURI(
        string memory newContractURI
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _contractURI = newContractURI;
    }

    /**
     * @dev Returns the base URI for the token metadata.
     * @return The base URI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Checks if the contract supports a given interface.
     * @param interfaceId The interface identifier.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            IERC165,
            ERC2981,
            ERC721EnumerableUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        if (interfaceId == type(IERC2981).interfaceId) {
            return true;
        }
        if (interfaceId == type(INFT).interfaceId) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation.
     * Can only be called by users with the DEFAULT_ADMIN_ROLE.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * @dev Burns a token and resets its royalty information.
     * @param tokenId The ID of the token to burn.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    /**
     * @dev Returns the contract URI.
     * @return The contract URI.
     */
    function contractURI() external view virtual returns (string memory) {
        return _contractURI;
    }
}

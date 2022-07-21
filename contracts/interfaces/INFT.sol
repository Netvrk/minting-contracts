// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface INFT is IERC165 {
    // Mint item
    function mintItem(address user) external returns (uint256);

    // Set base URI
    function setBaseURI(string memory baseTokenURI) external;
}

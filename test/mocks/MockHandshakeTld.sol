// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";

import "contracts/HandshakeNft.sol";
import "contracts/TldClaimManager.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockHandshakeTld is IHandshakeTld, ERC721 {
    constructor() ERC721("test", "test") {}

    function register(address _addr, string calldata _domain) external {}

    function ownerOf(uint256 _tokenId)
        public
        view
        override(ERC721, IHandshakeTld)
        returns (address)
    {
        return super.ownerOf(_tokenId);
    }

    function isApprovedOrOwner(address _operator, uint256 _id) external view returns (bool) {
        return true;
    }

    function setTldClaimManager(ITldClaimManager _manager) external {}
}

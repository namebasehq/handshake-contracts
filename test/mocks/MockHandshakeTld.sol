// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";
import {Namehash} from "utils/Namehash.sol";

import "contracts/HandshakeNft.sol";
import "contracts/TldClaimManager.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockHandshakeTld is IHandshakeTld, ERC721 {
    mapping(uint256 => address) private approvedMap;

    constructor() ERC721("test", "test") {}

    function register(address _addr, string calldata _domain) external {
        bytes32 namehash = Namehash.getTldNamehash(_domain);
        uint256 id = uint256(namehash);
        _mint(_addr, id);
    }

    function register(address _addr, uint256 _id) external {
        _mint(_addr, _id);
    }

    function ownerOf(uint256 _tokenId)
        public
        view
        override(ERC721, IHandshakeTld)
        returns (address)
    {
        return ERC721.ownerOf(_tokenId);
    }

    function isApprovedOrOwner(address _operator, uint256 _id) external view returns (bool) {
        address owner = ownerOf(_id);
        return _operator == owner || isApprovedForAll(owner, _operator);
    }

    function setTldClaimManager(ITldClaimManager _manager) external {}

    function addApprovedAddress(address _operator, uint256 _id) external {
        approvedMap[_id] = _operator;
    }

    function namehashToLabelMap(bytes32) external pure returns (string memory) {
        require(false, "not implemented");
        return "";
    }
}

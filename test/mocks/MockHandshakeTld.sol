// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {Namehash} from "utils/Namehash.sol";

import "contracts/HandshakeNft.sol";
import "contracts/TldClaimManager.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "interfaces/IResolver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockHandshakeTld is IHandshakeTld, ERC721 {
    mapping(uint256 => address) private approvedMap;
    mapping(uint256 => mapping(address => bool)) idToAddressToApproved;
    mapping(bytes32 => ISldRegistrationStrategy) public registrationStrategy;

    mapping(bytes32 => IResolver) public tokenResolverMap;

    string public label;

    constructor() ERC721("test", "test") {}

    function addRegistrationStrategy(bytes32 _parentNamehash, ISldRegistrationStrategy _strategy)
        public
    {
        registrationStrategy[_parentNamehash] = _strategy;
    }

    function register(address _addr, string calldata _domain) external {
        bytes32 namehash = Namehash.getTldNamehash(_domain);
        uint256 id = uint256(namehash);
        _mint(_addr, id);
    }

    function name(bytes32) public view returns (string memory) {
        return label;
    }

    function setLabel(string calldata _label) public {
        label = _label;
    }

    function register(address _addr, uint256 _id) external {
        _mint(_addr, _id);
    }

    function registerWithResolver(
        address _addr,
        string calldata _domain,
        ISldRegistrationStrategy _strategy
    ) external {}

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

    function setResolver(bytes32 _namehash, IResolver _resolver) public {
        tokenResolverMap[_namehash] = _resolver;
    }

    function addMapping(uint256 _id, address _addr, bool _approved) public {
        idToAddressToApproved[_id][_addr] = _approved;
    }

    function setTldClaimManager(ITldClaimManager _manager) external {}

    function addApprovedAddress(address _operator, uint256 _id) external {
        approvedMap[_id] = _operator;
    }

    function namehashToLabelMap(bytes32 _b) external view returns (string memory) {
        return (name(_b));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {console} from "forge-std/console.sol";
import {Namehash} from "utils/Namehash.sol";

import "contracts/HandshakeNft.sol";

contract MockHandshakeNft is HandshakeNft {
    uint256 public ExpiryTimestamp;
    string public DomainName;
    string public ParentName;

    mapping(bytes32 => string) nodeToName;

    constructor() HandshakeNft("test", "test") {}

    function setExpiry(uint256 _expiry) public {
        ExpiryTimestamp = _expiry;
    }

    function expiry(bytes32) public view override returns (uint256 _expiry) {
        _expiry = ExpiryTimestamp;
    }

    function setParent(string memory _name) public {
        ParentName = _name;
    }

    function parent(bytes32) public view override returns (string memory _parentName) {
        _parentName = ParentName;
    }

    function setName(string memory _name) public {
        DomainName = _name;
    }

    function mint(address _owner, uint256 _id) public {
        _mint(_owner, _id);
    }

    function name(bytes32 _namehash) external view override returns (string memory _name) {
        return nodeToName[_namehash];
    }

    function setName(bytes32 _namehash, string calldata _name) public {
        nodeToName[_namehash] = _name;
    }
}

// SPDX-License-Identifier: UNLICENSED


import "src/contracts/assets/HandshakeERC721.sol";
import "interfaces/registration/ITldClaimManager.sol";
import "interfaces/registration/ISldPriceStrategy.sol";


pragma solidity ^0.8.15;

contract TldNft is HandshakeERC721 {


    ITldClaimManager public ClaimManager;

    mapping(bytes32 => ISldPriceStrategy) public SldDefaultPriceStrategy;

    constructor() HandshakeERC721("HTLD", "Handshake Top Level Domain"){

    }

    function setTldClaimManager(ITldClaimManager _manager) public onlyOwner {
        ClaimManager = _manager;
    }

    function mint(address _addr, string calldata _domain) external {
        bytes32 namehash = keccak256(abi.encodePacked(_domain));
        require(address(ClaimManager) == msg.sender, "not authorised");
        _safeMint(_addr, uint256(namehash));
        NamehashToLabelMap[namehash] = _domain;
    }

    modifier tldOwner(bytes32 _namehash) {
        require(msg.sender == ownerOf(uint256(_namehash)), "Caller is not owner of TLD");
        _;
    }

    function updateSldPricingStrategy(bytes32 _namehash, ISldPriceStrategy _strategy) public tldOwner(_namehash) {
        SldDefaultPriceStrategy[_namehash] = _strategy;
    }




}
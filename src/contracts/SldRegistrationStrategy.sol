// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ISldRegistrationStrategy.sol";
import "contracts/HandshakeERC721.sol";

contract SldRegistrationStrategy is ISldRegistrationStrategy {
    mapping(bytes32 => uint256) public FixedPrice;
    address public AuthorisedAddress;

    HandshakeERC721 public NftContract;
    bytes32 public ParentHash;

    constructor(bytes32 _namehash, HandshakeERC721 _nft) {
        NftContract = _nft;
        ParentHash = _namehash;
    }

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength
    ) external view returns (uint256) {
        return 0;
    }

    function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || //ERC165
            interfaceID == this.getPriceInDollars.selector;
    }

    function updatePrice(bytes32 _parentHash, uint256 _price) external {
        require(msg.sender == AuthorisedAddress, "not authorised");
        FixedPrice[_parentHash] = _price;
    }
}

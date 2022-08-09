// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/ISldPriceStrategy.sol";

contract SldPriceStrategy is ISldPriceStrategy {
    mapping(bytes32 => uint256) public FixedPrice;
    address public AuthorisedAddress;

    constructor() {
        AuthorisedAddress = msg.sender;
    }

    function getPriceInWei(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength,
        bytes32[] calldata _proofs
    ) external view returns (uint256) {
        return 0;
    }

    function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || //ERC165
            interfaceID == this.getPriceInWei.selector;
    }

    function updatePrice(bytes32 _parentHash, uint256 _price) external {
        require(msg.sender == AuthorisedAddress, "not authorised");
        FixedPrice[_parentHash] = _price;
    }
}

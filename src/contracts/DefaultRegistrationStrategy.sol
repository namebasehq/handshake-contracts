// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "interfaces/ISldRegistrationStrategy.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "interfaces/IHandshakeSld.sol";


contract DefaultRegistrationStrategy is ISldRegistrationStrategy, ERC165 {

    IHandshakeSld SubdomainContract;

    constructor(IHandshakeSld _sld) {
        SubdomainContract = _sld;
    }

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength
    ) external view returns (uint256){

    }

    function supportsInterface(bytes4 interfaceId) public override(ERC165, IERC165) view returns(bool) {
        return interfaceId == this.getPriceInDollars.selector || super.supportsInterface(interfaceId);
    }
}


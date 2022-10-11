// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISldRegistrationStrategy is IERC165 {
    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength
    ) external view returns (uint256);
}

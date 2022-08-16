// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISldPriceStrategy is IERC165 {
    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength,
        bytes32[] calldata _proofs
    ) external view returns (uint256);
}

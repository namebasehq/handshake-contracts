// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISldPriceStrategy is IERC165 {

    function getPriceInWei(address _buyingAddress, bytes32 _parentNamehash, string memory _label, uint256 _registrationLength, bytes32[] calldata _proofs) view external returns(uint256);

}
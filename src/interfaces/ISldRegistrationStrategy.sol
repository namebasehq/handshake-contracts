// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ISldRegistrationStrategy is IERC165 {
    event PremiumNameSet(bytes32 indexed _tokenNamehash, uint256 _price, string _label);
    event ReservedNameSet(bytes32 indexed _tokenNamehash, address indexed _claimant, string _label);
    event LengthCostSet(bytes32 indexed _tokenNamehash, uint256[] _prices);
    event MultiYearDiscountSet(bytes32 indexed _tokenNamehash, uint256[] _discounts);
    event EnabledSet(bytes32 indexed _tokenNamehash, bool _enabled);

    function isEnabled(bytes32 _parentNamehash) external view returns (bool);

    function getPriceInDollars(
        address _buyingAddress,
        bytes32 _parentNamehash,
        string memory _label,
        uint256 _registrationLength,
        bool _isRenewal
    ) external view returns (uint256);
}

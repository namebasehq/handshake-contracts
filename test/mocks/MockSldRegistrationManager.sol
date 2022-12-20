// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "interfaces/IHandshakeSld.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ILabelValidator.sol";
import "interfaces/ISldRegistrationManager.sol";
import "structs/SldRegistrationDetail.sol";

contract MockSldRegistrationManager is ISldRegistrationManager {
    mapping(bytes32 => SldRegistrationDetail) public sldRegistrationHistory;

    function addSldDetail(bytes32 _sldNamehash, SldRegistrationDetail memory _detail) private {
        sldRegistrationHistory[_sldNamehash] = _detail;
    }

    function addSldDetail(
        bytes32 _sldNamehash,
        uint80 _registrationTime,
        uint80 _registrationLength,
        uint96 _registrationPrice,
        uint128[10] calldata
    ) public {
        SldRegistrationDetail memory detail = SldRegistrationDetail(
            _registrationTime,
            _registrationLength,
            _registrationPrice
        );
        addSldDetail(_sldNamehash, detail);
    }

    function registerSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash,
        address _recipient
    ) external payable {}

    function renewSld(string calldata _label, bytes32 _parentNamehash, uint80 _registrationLength)
        external
        payable
    {}

    function getRenewalPricePerDay(
        address, //msg.sender
        bytes32, //_parentNamehash
        string calldata, //_label
        uint256 //_registrationLength
    ) public pure returns (uint256) {
        revert("not implemented");
    }
}

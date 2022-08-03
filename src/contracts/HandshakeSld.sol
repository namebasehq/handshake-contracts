// SPDX-License-Identifier: UNLICENSED

import "src/contracts/HandshakeERC721.sol";
import "src/contracts/HandshakeTld.sol";
import "src/contracts/SldCommitIntent.sol";
import "interfaces/ICommitIntent.sol";

pragma solidity ^0.8.15;

contract HandshakeSld is HandshakeERC721 {
    HandshakeTld public HandshakeTldContract;
    ICommitIntent public CommitIntent;
    IDomainValidator public LabelValidator;

    mapping(bytes32 => bytes32) public NamehashToParentMap;


    constructor() HandshakeERC721("HSLD", "Handshake Second Level Domain") {
        HandshakeTldContract = new HandshakeTld();
        HandshakeTldContract.transferOwnership(msg.sender);
        
        CommitIntent = new SldCommitIntent(msg.sender);
        LabelValidator = new DomainLabelValidator();
    }

    function purchaseSld(
        string calldata _label,
        bytes32 _secret,
        uint256 _registrationLength,
        bytes32 _parentNamehash
    ) public {
        require(LabelValidator.isValidLabel(_label), "invalid label");
        bytes32 namehash = getNamehash(_label, _parentNamehash);
        uint256 id = uint256(namehash);
        require(
            CommitIntent.allowedCommit(namehash, _secret, msg.sender),
            "commit not allowed"
        );

        _safeMint(msg.sender, id);

        NamehashToLabelMap[namehash] = _label;
        NamehashToParentMap[namehash] = _parentNamehash;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";

import "contracts/HandshakeNft.sol";
import "contracts/TldClaimManager.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HandshakeTld is HandshakeNft, IHandshakeTld {
    using SafeMath for uint256;
    ITldClaimManager public claimManager;

    mapping(bytes32 => ISldRegistrationStrategy) public sldDefaultRegistrationStrategy;

    address public claimManagerAddress;
    address public royaltyPayoutAddress;
    uint256 public royaltyPayoutAmount;

    constructor(ITldClaimManager _claimManager) HandshakeNft("TLD", "Top Level Domain") {
        claimManager = _claimManager;
    }

    function setTldClaimManager(ITldClaimManager _manager) public onlyOwner {
        claimManager = _manager;
    }

    function setRoyaltyPayoutAddress(address _addr) public onlyOwner {
        require(_addr != address(0), "cannot set to zero address");
        royaltyPayoutAddress = _addr;
    }

    function setRoyaltyPayoutAmount(uint256 _amount) public onlyOwner {
        require(_amount < 101, "10% maximum royalty on TLD");
        royaltyPayoutAmount = _amount;
    }

    function register(address _addr, string calldata _domain) external {
        // TLD node and token ID is full namehash with root 0x0 as parent
        bytes32 namehash = Namehash.getTldNamehash(_domain);
        require(address(claimManager) == msg.sender, "not authorised");
        _mint(_addr, uint256(namehash));
        namehashToLabelMap[namehash] = _domain;
    }

    modifier tldOwner(bytes32 _namehash) {
        require(msg.sender == ownerOf(uint256(_namehash)), "Caller is not owner of TLD");
        _;
    }

    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        uint256 divisor = royaltyPayoutAmount.div(10);
        uint256 amount = royaltyPayoutAmount == 0 || divisor == 0 ? 0 : salePrice.div(divisor);
        return (royaltyPayoutAddress, amount);
    }

    function ownerOf(uint256 _id)
        public
        view
        override(HandshakeNft, IHandshakeTld)
        returns (address)
    {
        return super.ownerOf(_id);
    }

    function isApprovedOrOwner(address _operator, uint256 _id)
        public
        view
        override(HandshakeNft, IHandshakeTld)
        returns (bool)
    {
        address owner = ownerOf(_id);
        return _operator == owner || isApprovedForAll(owner, _operator);
    }

}

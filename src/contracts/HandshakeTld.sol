// SPDX-License-Identifier: UNLICENSED

import "src/contracts/HandshakeERC721.sol";
import "interfaces/ITldClaimManager.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

pragma solidity ^0.8.15;

contract HandshakeTld is HandshakeERC721 {
    using SafeMath for uint256;
    ITldClaimManager public ClaimManager;

    address public RoyaltyPayoutAddress;
    uint256 public RoyaltyPayoutAmount;

    constructor() HandshakeERC721("HTLD", "Handshake Top Level Domain") {}

    function setTldClaimManager(ITldClaimManager _manager) public onlyOwner {
        ClaimManager = _manager;
    }

    function setRoyaltyPayoutAddress(address _addr) public onlyOwner {
        require(_addr != address(0), "cannot set to zero address");
        RoyaltyPayoutAddress = _addr;
    }

    function setRoyaltyPayoutAmount(uint256 _amount) public onlyOwner {
        require(_amount < 101, "10% maximum royalty on TLD");
        RoyaltyPayoutAmount = _amount;
    }

    function mint(address _addr, string calldata _domain) external {
        bytes32 namehash = keccak256(abi.encodePacked(_domain));
        require(address(ClaimManager) == msg.sender, "not authorised");
        _safeMint(_addr, uint256(namehash));
        NamehashToLabelMap[namehash] = _domain;
    }

    modifier tldOwner(bytes32 _namehash) {
        require(msg.sender == ownerOf(uint256(_namehash)), "Caller is not owner of TLD");
        _;
    }

    function updateSldPricingStrategy(bytes32 _namehash, ISldPriceStrategy _strategy)
        public
        tldOwner(_namehash)
    {
        SldDefaultPriceStrategy[_namehash] = _strategy;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        uint256 divisor = RoyaltyPayoutAmount.div(10);
        uint256 amount = RoyaltyPayoutAmount == 0 || divisor == 0
            ? 0
            : salePrice.div(divisor);
        return (RoyaltyPayoutAddress, amount);
    }
}

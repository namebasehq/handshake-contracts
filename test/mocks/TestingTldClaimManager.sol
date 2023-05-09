import "contracts/TldClaimManager.sol";

contract TestingTldClaimManager is TldClaimManager {
    uint256 public globalExpiry;

    function setGlobalExpiry(uint256 _expiry) public {
        globalExpiry = _expiry;
    }

    function tldExpiry(bytes32) public view virtual override returns (uint256) {
        return globalExpiry == 0 ? type(uint64).max : globalExpiry;
    }

    // function claimTld(string calldata _domain, address _addr) public payable override {

    // }
}

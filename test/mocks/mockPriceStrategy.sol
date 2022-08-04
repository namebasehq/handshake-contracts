// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "interfaces/ISldPriceStrategy.sol";

contract MockPriceStrategy is ISldPriceStrategy{


function getPriceInWei(address _buyingAddress, bytes32 _parentNamehash, string memory _label, uint256 _registrationLength, bytes32[] calldata _proofs) view external returns (uint256){

return 0;
}

    function supportsInterface(bytes4 interfaceID) public override view returns (bool) {
        return
          interfaceID == this.supportsInterface.selector || // ERC165
          interfaceID == this.getPriceInWei.selector; 
    }

}

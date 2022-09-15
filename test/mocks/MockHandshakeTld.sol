// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console} from "forge-std/console.sol";

import "contracts/HandshakeNft.sol";
import "contracts/TldClaimManager.sol";
import "interfaces/IHandshakeTld.sol";
import "interfaces/ITldClaimManager.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MockHandshakeTld is IHandshakeTld {

    function register(address _addr, string calldata _domain) external{

    }

    function ownerOf(uint256 _id) external view returns(address){
        return address(0);
    }   

    function isApprovedOrOwner(address _operator, uint256 _id) external view returns(bool){
        return true;
    }

}
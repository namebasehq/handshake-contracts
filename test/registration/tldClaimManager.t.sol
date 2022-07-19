// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import "interfaces/registration/ITldClaimManager.sol";
import "src/contracts/registration/TldClaimManager.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract TldClaimManagerTests is Test {

    ITldClaimManager internal manager;

    bytes32 validMerkleRoot = 0x8440f47b2d349b35bb84843dc23a3768bdfe592fc11e977c48ee59c412d33eec;

    bytes32[15] validProofs;

    address validWallet = 0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42;


    function setUp() public {
        manager = new TldClaimManager();

    }

     function testClaimWithInvalidProofs() public {

     }

     function testClaimWithCorrectProofs() public {
        manager.setMerkleRoot(validMerkleRoot);

        bytes32[] memory proofs = new bytes32[](15);
        
        proofs[0] = 0x86c7361e7fd927669e6adeba95b3c1ba71686a32bbc8a5657f7a603c1435d53f;
        proofs[1] = 0x87d54213e3d7886d98391596a0f8dc12d1a527765da8f8c1f00671a62d191ecf;
        proofs[2] = 0x40166748979c1f5fd475ac41ccf0667e2420b67a6c6996a0db677e20bc85ca7b;
        proofs[3] = 0x10abc2e16a0671db44d4cb6c250f1529962012721032bb12b511d7b0407701a1;
        proofs[4] = 0xdc098917e2b7e26911d5e392ec467930c081802ef76d2f43a3cb0994af838521;
        proofs[5] = 0x6ee35263058a391e53edb586d9184df8dbc8fa4fe0bbb7e79ac28a04c0430ef8;
        proofs[6] = 0x60d2b22a2f07489ef9e73abd9da0128ae4de718ee814da5691b589b6dd60d172;
        proofs[7] = 0xf14ebecb770adb565462e22c1329155558bbefa475eaf8c3a5ce741e1513660c;
        proofs[8] = 0x231ea7c9e4869ffcebe52c5b2bb6091116e1c722b02c7476934313f2b402c0ad;
        proofs[9] = 0x331dbd144832ef10d157bc12538affc1f1c55efe395cbb8494c9706e1c66bad3;
        proofs[10] = 0x5bda95d9377a239fb189a01cac622ab905da5baebe8e435565ccad4455cd02ce;
        proofs[11] = 0xcfae86557f21d841839fec4a090bb731e99c8bec81f5696b0df5fe2530023554;
        proofs[12] = 0x2395509f7b8ae8a244797ff00eb3e3d3764892a18de9bd5740fe4db53cb7acb6;
        proofs[13] = 0xdb69769459d33ac14d09ed9cb840fe27b3ff704e337ae69663e003cfb134f54b;
        proofs[14] = 0xa895f65e130c88b9c7abd18b1721f43e39f27bb08a7858dca7759722763c239b;

        bool result = manager.canClaim(validWallet, 0x0, proofs);
     }

     function testClaimWithTldThatDoesNotExist() public {

     }

     function testClaimWithMerkleRootNotSet() public {

     }

     function testOwnerCanUpdateMerkleRoot() public {

     }

     function testUserCannotUpdateMerkleRoot() public {

     }

     function testClaimWhenTldAlreadyClaimed() public {

     }
}
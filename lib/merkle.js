const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { soliditySha3 } = require('web3-utils');

class Merkle {
  constructor() {
    this.whitelistAddresses = [];


    this.whitelistAddresses = [
                ["0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42", "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658"]
                                , ["0x8845938e23D338552fA58cdd1B599C8eab1bF597", 0x02]
                                , ["0x2CFe89E3BAa8845954FbD257Ad351e9f6570291a", 0x03]
                                , ["0x082Fc1776d44f69988C475958A0505A5BC2cd77b", 0x04]
                                , ["0x00000000236AA20a26dbdD359362f4D517E6138E", 0x05]
                              ];
  



    this.generateMerkleTree = function() {
        const leaves = this.whitelistAddresses.map((item) =>
          soliditySha3(item[0], item[1]),
        );
        var tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        return tree;
      }
    
      this.getMerkleRoot = function() {
        var tree = this.merkleTree;

        return `0x${tree.getRoot().toString('hex')}`
      };
    
      this.getProof = function(addr, qty) {
        var tree = this.merkleTree;
        return tree.getHexProof(soliditySha3(addr, qty));
      }

      this.generateTrees = function() {
        console.log('Generating MerkleTrees...');
        this.merkleTree = this.generateMerkleTree();
     
    
           
        console.log('Printing the trees...');
        console.log('Tree 0\n', this.merkleTrees[0].toString());
        console.log('Tree 1\n', this.merkleTrees[1].toString());
        
      }

      this.addAddress = function(addr, qty) {
        this.whitelistAddresses.push([addr, qty]);
      }

      this.merkleTree = this.generateMerkleTree();
      console.log(`merkle root: ${this.getMerkleRoot()})`);
      console.log(`merkle proofs: ${this.getProof("0x91769843CEc84Adcf7A48DF9DBd9694A39f44b42", "0x9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658")}`)
        console.log('\n================\n\n');
  }

}

m = new Merkle();



